"""학회 포스터 QR코드 생성 스크립트.

실행하면 같은 폴더에 poster_qr.png(인쇄용 고해상도)와
poster_qr.svg(벡터, 확대해도 안 깨짐)가 생성됩니다.
"""

from pathlib import Path

import qrcode
import qrcode.image.svg

# main 브랜치 blob 링크: 스캔하면 GitHub 미리보기가 뜨고,
# 나중에 같은 경로에 새 커밋을 올리면 QR 수정 없이 최신 버전이 보입니다.
URL = (
    "https://github.com/abbosaliboev/ICCAS_2026.git"
)

# 출력 위치: 스크립트가 있는 폴더 (어디서 실행하든 동일)
OUT_DIR = Path(__file__).parent


def make_qr(image_factory=None):
    qr = qrcode.QRCode(
        # H: 코드의 30%가 가려지거나 번져도 인식됨 (인쇄용 권장)
        error_correction=qrcode.constants.ERROR_CORRECT_H,
        box_size=40,  # 모듈 하나당 40픽셀 → 인쇄해도 선명한 고해상도
        border=4,     # QR 규격상 최소 여백 (지우면 인식률 떨어짐)
    )
    qr.add_data(URL)
    qr.make(fit=True)
    return qr.make_image(
        image_factory=image_factory,
        fill_color="black",
        back_color="white",
    )


if __name__ == "__main__":
    png = make_qr()
    png_path = OUT_DIR / "poster_qr.png"
    png.save(png_path)
    print(f"{png_path} 저장 완료 ({png.pixel_size}x{png.pixel_size}px)")

    svg = make_qr(image_factory=qrcode.image.svg.SvgPathImage)
    svg_path = OUT_DIR / "poster_qr.svg"
    svg.save(svg_path)
    print(f"{svg_path} 저장 완료 (벡터)")

    print("\n인쇄 전에 폰 카메라로 스캔 테스트 해보세요!")
    print(f"링크: {URL}")
