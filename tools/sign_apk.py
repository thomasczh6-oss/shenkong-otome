#!/usr/bin/env python3
"""给 Godot 导出的未签名 APK 做 zipalign + APK Signature Scheme v2 签名（纯 Python，不需要 Android SDK）。

Godot 导出签名包需要 Android SDK 里的 apksigner；在没有 SDK 的环境里，先用 Godot 导出未签名 APK，
再用本脚本对齐并签名。minSdk ≥ 24 时 v2 签名就够了（不需要 v1 / JAR 签名）。

用法：
  python tools/sign_apk.py in.apk out.apk --keystore debug.keystore --alias androiddebugkey --pass android
密钥库为 JKS / PKCS12，会调用 JDK 自带的 keytool 转成 PKCS12 读取。
校验：pip install apksigtool && apksigtool verify out.apk
"""
import argparse
import hashlib
import os
import struct
import subprocess
import tempfile
import zipfile

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.serialization import pkcs12

SIG_RSA_PKCS1_SHA256 = 0x0103
V2_BLOCK_ID = 0x7109871A
CHUNK = 1024 * 1024


# ---------------- zipalign ----------------

def zipalign(src, dst):
    """未压缩条目的数据按 4 字节对齐，.so 按 4096 对齐（与 zipalign -p 4 等效）。"""
    with open(src, "rb") as f:
        data = f.read()
    zf = zipfile.ZipFile(src)
    infos = sorted(zf.infolist(), key=lambda i: i.header_offset)
    out = bytearray()
    cd = bytearray()
    for info in infos:
        off = info.header_offset
        sig, ver, flag, meth, t, d, crc, csz, usz, nlen, xlen = struct.unpack("<IHHHHHIIIHH", data[off:off + 30])
        assert sig == 0x04034B50
        name = data[off + 30:off + 30 + nlen]
        if flag & 0x08:
            raise SystemExit("不支持带 data descriptor 的条目")
        body = data[off + 30 + nlen + xlen:off + 30 + nlen + xlen + csz]
        extra = b""
        if meth == 0:
            align = 4096 if name.endswith(b".so") else 4
            pos = len(out) + 30 + nlen
            pad = (-pos) % align
            extra = b"\x00" * pad
        new_off = len(out)
        out += struct.pack("<IHHHHHIIIHH", sig, ver, flag, meth, t, d, crc, csz, usz, nlen, len(extra)) + name + extra + body
        # 中央目录条目：沿用原条目，只改本地头偏移
        cd += _central_entry(data, zf, info, new_off)
    cd_off = len(out)
    out += cd
    out += struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, len(infos), len(infos), len(cd), cd_off, 0)
    with open(dst, "wb") as f:
        f.write(out)


def _central_entry(data, zf, info, new_off):
    # 在原中央目录里找到这个条目的原始字节
    if not hasattr(zf, "_cd_map"):
        eocd = data.rfind(b"PK\x05\x06")
        cd_size, cd_off = struct.unpack("<II", data[eocd + 12:eocd + 20])
        p = cd_off
        zf._cd_map = {}
        while p < cd_off + cd_size:
            nlen, xlen, clen = struct.unpack("<HHH", data[p + 28:p + 34])
            lho = struct.unpack("<I", data[p + 42:p + 46])[0]
            zf._cd_map[lho] = data[p:p + 46 + nlen + xlen + clen]
            p += 46 + nlen + xlen + clen
    raw = bytearray(zf._cd_map[info.header_offset])
    raw[42:46] = struct.pack("<I", new_off)
    return bytes(raw)


# ---------------- v2 签名 ----------------

def lp(b):
    return struct.pack("<I", len(b)) + b


def chunk_digest(sections):
    digests = []
    for sec in sections:
        for i in range(0, len(sec), CHUNK):
            c = sec[i:i + CHUNK]
            digests.append(hashlib.sha256(b"\xa5" + struct.pack("<I", len(c)) + c).digest())
    return hashlib.sha256(b"\x5a" + struct.pack("<I", len(digests)) + b"".join(digests)).digest()


def sign_v2(src, dst, key, cert_der):
    with open(src, "rb") as f:
        apk = f.read()
    eocd_off = apk.rfind(b"PK\x05\x06")
    cd_size, cd_off = struct.unpack("<II", apk[eocd_off + 12:eocd_off + 20])
    entries, cd, eocd = apk[:cd_off], apk[cd_off:cd_off + cd_size], apk[eocd_off:]

    digest = chunk_digest([entries, cd, eocd])
    digests = lp(lp(struct.pack("<I", SIG_RSA_PKCS1_SHA256) + lp(digest)))
    signed_data = digests + lp(lp(cert_der)) + lp(b"")
    sig = key.sign(signed_data, padding.PKCS1v15(), hashes.SHA256())
    pub = key.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
    signer = lp(signed_data) + lp(lp(struct.pack("<I", SIG_RSA_PKCS1_SHA256) + lp(sig))) + lp(pub)
    value = lp(lp(signer))

    pair = struct.pack("<I", V2_BLOCK_ID) + value
    pairs = struct.pack("<Q", len(pair)) + pair
    size = len(pairs) + 8 + 16
    block = struct.pack("<Q", size) + pairs + struct.pack("<Q", size) + b"APK Sig Block 42"

    new_eocd = bytearray(eocd)
    new_eocd[16:20] = struct.pack("<I", cd_off + len(block))
    with open(dst, "wb") as f:
        f.write(entries + block + cd + bytes(new_eocd))


def load_key(keystore, alias, password):
    with tempfile.TemporaryDirectory() as td:
        p12 = os.path.join(td, "k.p12")
        subprocess.run(["keytool", "-importkeystore", "-srckeystore", keystore, "-srcstorepass", password,
                        "-srcalias", alias, "-destkeystore", p12, "-deststoretype", "PKCS12",
                        "-deststorepass", password, "-destkeypass", password, "-noprompt"],
                       check=True, capture_output=True)
        with open(p12, "rb") as f:
            key, cert, _ = pkcs12.load_key_and_certificates(f.read(), password.encode())
    assert isinstance(key, rsa.RSAPrivateKey), "目前只支持 RSA 密钥"
    return key, cert.public_bytes(serialization.Encoding.DER)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--keystore", default=os.path.expanduser("~/.local/share/godot/keystores/debug.keystore"))
    ap.add_argument("--alias", default="androiddebugkey")
    ap.add_argument("--pass", dest="password", default="android")
    a = ap.parse_args()
    key, cert = load_key(a.keystore, a.alias, a.password)
    aligned = a.dst + ".aligned"
    zipalign(a.src, aligned)
    sign_v2(aligned, a.dst, key, cert)
    os.remove(aligned)
    print(f"已签名：{a.dst}")


if __name__ == "__main__":
    main()
