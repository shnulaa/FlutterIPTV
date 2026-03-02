#!/usr/bin/env python3
"""
批量将PNG图片转换为WebP格式
保持文件名不变，只改扩展名
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("错误: 需要安装 Pillow 库")
    print("请运行: pip install Pillow")
    sys.exit(1)

def convert_png_to_webp(input_dir, output_dir=None, quality=80):
    """
    将目录下的所有PNG转换为WebP
    
    Args:
        input_dir: 输入目录
        output_dir: 输出目录（如果为None，则覆盖原文件）
        quality: WebP质量 (0-100)，默认80
    """
    input_path = Path(input_dir)
    
    if not input_path.exists():
        print(f"错误: 目录不存在 - {input_dir}")
        return
    
    # 如果没有指定输出目录，使用输入目录
    if output_dir is None:
        output_path = input_path
        overwrite = True
    else:
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        overwrite = False
    
    # 获取所有PNG文件
    png_files = list(input_path.glob("*.png"))
    
    if not png_files:
        print(f"警告: 在 {input_dir} 中没有找到PNG文件")
        return
    
    print(f"\n找到 {len(png_files)} 个PNG文件")
    print(f"质量设置: {quality}")
    print(f"输出目录: {output_path}")
    print("-" * 50)
    
    total_original_size = 0
    total_webp_size = 0
    converted_count = 0
    
    for png_file in png_files:
        try:
            # 打开PNG图片
            img = Image.open(png_file)
            
            # 生成WebP文件名
            webp_filename = png_file.stem + ".webp"
            webp_path = output_path / webp_filename
            
            # 获取原始文件大小
            original_size = png_file.stat().st_size
            
            # 转换为WebP
            img.save(webp_path, "WEBP", quality=quality, method=6)
            
            # 获取WebP文件大小
            webp_size = webp_path.stat().st_size
            
            # 计算压缩率
            reduction = (1 - webp_size / original_size) * 100
            
            print(f"✓ {png_file.name}")
            print(f"  {original_size/1024:.1f}KB → {webp_size/1024:.1f}KB (减少 {reduction:.1f}%)")
            
            total_original_size += original_size
            total_webp_size += webp_size
            converted_count += 1
            
            # 如果是覆盖模式，删除原PNG文件
            if overwrite:
                png_file.unlink()
                print(f"  已删除原文件")
            
        except Exception as e:
            print(f"✗ 转换失败: {png_file.name}")
            print(f"  错误: {e}")
    
    # 打印总结
    print("-" * 50)
    print(f"\n转换完成!")
    print(f"成功转换: {converted_count}/{len(png_files)} 个文件")
    print(f"原始总大小: {total_original_size/1024/1024:.2f} MB")
    print(f"WebP总大小: {total_webp_size/1024/1024:.2f} MB")
    
    if total_original_size > 0:
        total_reduction = (1 - total_webp_size / total_original_size) * 100
        saved_mb = (total_original_size - total_webp_size) / 1024 / 1024
        print(f"总压缩率: {total_reduction:.1f}%")
        print(f"节省空间: {saved_mb:.2f} MB")

if __name__ == "__main__":
    # 默认转换 assets/icons/img 目录
    input_dir = "assets/icons/img"
    
    # 可以通过命令行参数指定目录
    if len(sys.argv) > 1:
        input_dir = sys.argv[1]
    
    # 质量参数（可选）
    quality = 80
    if len(sys.argv) > 2:
        quality = int(sys.argv[2])
    
    print("=" * 50)
    print("PNG to WebP 批量转换工具")
    print("=" * 50)
    
    convert_png_to_webp(input_dir, quality=quality)
