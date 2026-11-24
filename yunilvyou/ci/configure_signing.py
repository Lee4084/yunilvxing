import base64
import hashlib
import json
import plistlib
import re
import ssl
import subprocess
from pathlib import Path


BUNDLE_ID = "com.yunilvxing.app"
PROFILE_NAME = "YouniTravel_AppStore"
PROFILE_DIRECTORY = Path.home() / "Library/MobileDevice/Provisioning Profiles"
PROFILE_DIRECTORY.mkdir(parents=True, exist_ok=True)


def apple(*arguments):
    result = subprocess.run(
        ["app-store-connect", *arguments, "--json"],
        check=True, capture_output=True, text=True,
    )
    payload = json.loads(result.stdout)
    if isinstance(payload, dict) and "data" in payload:
        payload = payload["data"]
    return payload if isinstance(payload, list) else [payload]


def attributes(resource):
    return resource.get("attributes", resource)


def certificate_fingerprint(data):
    return hashlib.sha256(data).digest()


pem = subprocess.check_output(["security", "find-certificate", "-a", "-p"], text=True)
installed = {
    certificate_fingerprint(ssl.PEM_cert_to_DER_cert(value))
    for value in re.findall(
        r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", pem, re.S
    )
}
certificates = apple("certificates", "list", "--type", "DISTRIBUTION", "IOS_DISTRIBUTION")
matching = [
    item for item in certificates
    if attributes(item).get("certificateContent")
    and certificate_fingerprint(base64.b64decode(attributes(item)["certificateContent"])) in installed
]
if len(matching) != 1:
    raise SystemExit("The uploaded yunilvxing distribution certificate must match exactly one Apple certificate.")
certificate = matching[0]
fingerprint = certificate_fingerprint(base64.b64decode(attributes(certificate)["certificateContent"]))

bundles = apple("bundle-ids", "list", "--bundle-id-identifier", BUNDLE_ID, "--strict-match-identifier")
bundles = [item for item in bundles if attributes(item).get("identifier") == BUNDLE_ID]
if len(bundles) != 1:
    raise SystemExit("com.yunilvxing.app is not registered in the selected Apple developer account.")
bundle = bundles[0]


def install_profile(resource):
    content = attributes(resource).get("profileContent")
    if not content:
        resource = apple("profiles", "get", resource["id"])[0]
        content = attributes(resource).get("profileContent")
    if not content:
        return False
    data = base64.b64decode(content)
    temporary = PROFILE_DIRECTORY / ".youni-profile.mobileprovision"
    temporary.write_bytes(data)
    try:
        decoded = plistlib.loads(subprocess.check_output(["security", "cms", "-D", "-i", str(temporary)]))
        identifier = decoded.get("Entitlements", {}).get("application-identifier", "")
        compatible = identifier.endswith("." + BUNDLE_ID) and any(
            certificate_fingerprint(value) == fingerprint
            for value in decoded.get("DeveloperCertificates", [])
        )
        if not compatible:
            return False
        (PROFILE_DIRECTORY / (decoded["UUID"] + ".mobileprovision")).write_bytes(data)
        return True
    finally:
        temporary.unlink(missing_ok=True)


profiles = apple(
    "bundle-ids", "profiles", "--bundle-ids", bundle["id"],
    "--type", "IOS_APP_STORE", "--state", "ACTIVE",
)
if not any(install_profile(profile) for profile in profiles):
    profile = apple(
        "profiles", "create", bundle["id"], "--certificate-ids", certificate["id"],
        "--type", "IOS_APP_STORE", "--name", PROFILE_NAME,
    )[0]
    if not install_profile(profile):
        raise SystemExit("The created App Store provisioning profile does not match this app and certificate.")
