#!/usr/bin/env python3

import os
import time
import csv
import glob
import urllib.request
import uuid
from pathlib import Path
import cv2
import easyocr
import numpy as np
from datetime import datetime
from PIL import Image, ImageDraw, ImageFont

class OCRProcessor:
    def __init__(self):
        self.reader = easyocr.Reader(['ja', 'en'], gpu=False)
        self.images_dir = Path('images')
        self.process_dir = Path('process')
        self.result_dir = Path('result')
        self.fonts_dir = Path('fonts')
        
        # ディレクトリが存在しない場合は作成
        for directory in [self.images_dir, self.process_dir, self.result_dir, self.fonts_dir]:
            directory.mkdir(exist_ok=True)
        
        # 日本語フォントを準備
        self.font = self.get_japanese_font()
    
    def get_japanese_font(self):
        """日本語フォントを取得（自動ダウンロード機能付き）"""
        font_path = self.fonts_dir / "NotoSansCJK-Regular.ttc"
        
        # フォントファイルが存在しない場合はダウンロード
        if not font_path.exists():
            print("日本語フォントをダウンロード中...")
            try:
                font_url = "https://github.com/googlefonts/noto-cjk/raw/main/Sans/OTC/NotoSansCJK-Regular.ttc"
                urllib.request.urlretrieve(font_url, font_path)
                print("日本語フォントのダウンロードが完了しました")
            except Exception as e:
                print(f"フォントのダウンロードに失敗しました: {e}")
                # システムフォントの検索
                system_fonts = [
                    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
                    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                    "/System/Library/Fonts/Arial.ttf"  # macOS
                ]
                
                for system_font in system_fonts:
                    if Path(system_font).exists():
                        try:
                            return ImageFont.truetype(system_font, 16)
                        except:
                            continue
                
                # デフォルトフォントを使用
                return ImageFont.load_default()
        
        try:
            return ImageFont.truetype(str(font_path), 16)
        except Exception as e:
            print(f"フォントの読み込みに失敗しました: {e}")
            return ImageFont.load_default()
    
    def get_image_files(self):
        """imagesディレクトリから画像ファイルを取得"""
        image_extensions = ['*.jpg', '*.jpeg', '*.png', '*.bmp', '*.tif', '*.tiff', '*.webp']
        image_files = []
        
        for ext in image_extensions:
            image_files.extend(self.images_dir.glob(ext))
            image_files.extend(self.images_dir.glob(ext.upper()))
        
        return image_files
    
    def generate_unique_filename(self, original_filename, suffix=""):
        """ユニークなファイル名を生成"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id = str(uuid.uuid4())[:8]
        original_stem = Path(original_filename).stem
        original_ext = Path(original_filename).suffix
        
        if suffix:
            return f"{timestamp}_{unique_id}_{suffix}_{original_stem}{original_ext}"
        else:
            return f"{timestamp}_{unique_id}_{original_stem}{original_ext}"
    
    def process_image(self, image_path):
        """単一画像のOCR処理"""
        try:
            # PIL経由で読み込み（CCITTFAX4等OpenCVが対応しない形式も処理可能）
            # グレースケール画像は L モードのまま保持し、RGB強制変換による品質低下を防ぐ
            raw_img = Image.open(str(image_path))
            if raw_img.mode in ('1', 'P', 'RGBA', 'CMYK'):
                pil_img = raw_img.convert('RGB')
            elif raw_img.mode == 'L':
                pil_img = raw_img  # グレースケールはそのまま
            else:
                pil_img = raw_img.convert('RGB')
            image = cv2.cvtColor(np.array(pil_img, dtype=np.uint8),
                                 cv2.COLOR_GRAY2BGR if pil_img.mode == 'L' else cv2.COLOR_RGB2BGR)
            if image is None:
                print(f"画像の読み込みに失敗しました: {image_path}")
                return None

            # OCR実行（numpy配列で渡す）
            results = self.reader.readtext(np.array(pil_img, dtype=np.uint8))

            # 結果を処理用画像に描画
            processed_image = self.draw_results(image.copy(), results)

            # 処理済み画像は常にPNGで保存（元の拡張子に関わらず統一）
            unique_processed_name = self.generate_unique_filename(image_path.stem + '.png', "processed")
            output_image_path = self.process_dir / unique_processed_name
            cv2.imwrite(str(output_image_path), processed_image)
            
            # CSV用データを準備
            csv_data = []
            for (bbox, text, confidence) in results:
                # バウンディングボックスの座標を取得
                top_left = bbox[0]
                bottom_right = bbox[2]
                
                csv_data.append({
                    'original_filename': image_path.name,
                    'processed_filename': unique_processed_name,
                    'text': text,
                    'confidence': confidence,
                    'x1': int(top_left[0]),
                    'y1': int(top_left[1]),
                    'x2': int(bottom_right[0]),
                    'y2': int(bottom_right[1]),
                    'timestamp': datetime.now().isoformat()
                })
            
            # ユニークなファイル名でCSVファイルに保存
            unique_csv_name = self.generate_unique_filename(f"{image_path.stem}.csv", "result")
            csv_filename = self.result_dir / unique_csv_name
            self.save_to_csv(csv_data, csv_filename)
            
            print(f"処理完了: {image_path.name}")
            print(f"  -> 処理済み画像: {unique_processed_name}")
            print(f"  -> CSV結果: {unique_csv_name}")
            print(f"  -> 検出テキスト数: {len(results)}個")
            return True
            
        except Exception as e:
            print(f"画像処理中にエラーが発生しました: {image_path} - {str(e)}")
            return False
    
    def draw_results(self, image, results):
        """OCR結果を画像に描画（日本語対応）"""
        # OpenCVからPILに変換
        pil_image = Image.fromarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        draw = ImageDraw.Draw(pil_image)
        
        for (bbox, text, confidence) in results:
            # バウンディングボックスの座標を取得
            points = np.array(bbox, dtype=np.int32)
            
            # 矩形を描画
            bbox_coords = [(int(point[0]), int(point[1])) for point in points]
            draw.polygon(bbox_coords, outline=(0, 255, 0), width=2)
            
            # テキスト位置を計算
            text_x = int(bbox[0][0])
            text_y = int(bbox[0][1]) - 25
            
            # テキストが画像の上端を超えないよう調整
            if text_y < 0:
                text_y = int(bbox[2][1]) + 5
            
            # テキストサイズを取得
            try:
                bbox_text = draw.textbbox((0, 0), text, font=self.font)
                text_width = bbox_text[2] - bbox_text[0]
                text_height = bbox_text[3] - bbox_text[1]
            except:
                # フォントがない場合のフォールバック
                text_width = len(text) * 10
                text_height = 16
            
            # テキストの背景を描画
            background_coords = [
                text_x, text_y - text_height - 2,
                text_x + text_width + 4, text_y + 2
            ]
            draw.rectangle(background_coords, fill=(0, 255, 0), outline=(0, 255, 0))
            
            # テキストを描画
            draw.text((text_x + 2, text_y - text_height), text, font=self.font, fill=(0, 0, 0))
            
            # 信頼度を追加表示
            confidence_text = f"{confidence:.2f}"
            confidence_y = text_y + 5
            draw.text((text_x + 2, confidence_y), confidence_text, font=self.font, fill=(255, 0, 0))
        
        # PILからOpenCVに変換して戻す
        return cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
    
    def save_to_csv(self, data, filename):
        """データをCSVファイルに保存（テキスト未検出時もヘッダーのみ作成）"""
        with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['original_filename', 'processed_filename', 'text', 'confidence', 'x1', 'y1', 'x2', 'y2', 'timestamp']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for row in data:
                writer.writerow(row)
    
    def run_continuous(self):
        """継続的な画像監視とOCR処理"""
        print("OCR処理を開始します。Ctrl+Cで終了します。")
        
        try:
            while True:
                image_files = self.get_image_files()
                
                if image_files:
                    print(f"{len(image_files)}個の画像ファイルが見つかりました。")
                    
                    for image_path in image_files:
                        # OCR処理を実行
                        success = self.process_image(image_path)
                        
                        if success:
                            # 処理完了後、元の画像ファイルを削除
                            try:
                                os.remove(image_path)
                                print(f"画像ファイルを削除しました: {image_path.name}")
                            except Exception as e:
                                print(f"ファイル削除中にエラーが発生しました: {image_path} - {str(e)}")
                
                # 1秒待機
                time.sleep(1)
                
        except KeyboardInterrupt:
            print("\nOCR処理を終了します。")

def main():
    processor = OCRProcessor()
    processor.run_continuous()

if __name__ == "__main__":
    main()