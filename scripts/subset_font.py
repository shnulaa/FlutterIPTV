#!/usr/bin/env python3
"""
字体子集化工具 - 只保留常用汉字
减少字体文件大小约80%
"""

import sys
import os

try:
    from fontTools import subset
    from fontTools.ttLib import TTFont
except ImportError:
    print("错误: 需要安装 fonttools 库")
    print("请运行: pip install fonttools brotli")
    sys.exit(1)

def subset_font(input_font, output_font, unicode_ranges=None):
    """
    对字体进行子集化
    
    Args:
        input_font: 输入字体文件路径
        output_font: 输出字体文件路径
        unicode_ranges: Unicode范围列表
    """
    if unicode_ranges is None:
        # 默认范围：常用汉字 + 基本符号
        unicode_ranges = [
            # 基本拉丁字母 + 扩展
            "U+0020-007F",  # 基本拉丁字母
            "U+00A0-00FF",  # 拉丁字母补充
            
            # 常用符号
            "U+2000-206F",  # 常用标点
            "U+3000-303F",  # CJK符号和标点
            "U+FF00-FFEF",  # 半角全角形式
            
            # 常用汉字（GB2312范围）
            "U+4E00-9FA5",  # CJK统一汉字（20,902个常用汉字）
            
            # 数字和常用符号
            "U+2010-2027",  # 标点符号
            "U+2030-205E",  # 其他符号
        ]
    
    # 构建子集选项
    options = subset.Options()
    options.flavor = None  # 保持原格式
    options.desubroutinize = True  # 简化字体
    
    # 创建子集器
    subsetter = subset.Subsetter(options=options)
    
    # 解析Unicode范围并转换为字符集
    unicodes = []
    for range_str in unicode_ranges:
        if '-' in range_str:
            # 范围格式: U+0020-007F
            start, end = range_str.replace('U+', '').split('-')
            start_code = int(start, 16)
            end_code = int(end, 16)
            unicodes.extend(range(start_code, end_code + 1))
        else:
            # 单个字符: U+0020
            code = int(range_str.replace('U+', ''), 16)
            unicodes.append(code)
    
    # 填充子集器
    subsetter.populate(unicodes=unicodes)
    
    # 加载字体
    font = TTFont(input_font)
    
    # 获取原始大小
    original_size = os.path.getsize(input_font)
    
    print(f"\n处理字体: {os.path.basename(input_font)}")
    print(f"原始大小: {original_size / 1024 / 1024:.2f} MB")
    print(f"保留字符数: {len(unicodes)}")
    
    # 执行子集化
    subsetter.subset(font)
    
    # 保存子集字体
    font.save(output_font)
    
    # 获取新大小
    new_size = os.path.getsize(output_font)
    reduction = (1 - new_size / original_size) * 100
    
    print(f"子集大小: {new_size / 1024 / 1024:.2f} MB")
    print(f"压缩率: {reduction:.1f}%")
    print(f"节省空间: {(original_size - new_size) / 1024 / 1024:.2f} MB")
    print(f"✓ 已保存到: {output_font}")

def main():
    print("=" * 60)
    print("字体子集化工具 - 只保留常用汉字（GB2312）")
    print("=" * 60)
    
    # 处理两个字体文件
    fonts = [
        ("assets/fonts/SourceHanSansSC-Bold.otf", 
         "assets/fonts/SourceHanSansSC-Bold-Subset.otf"),
        ("assets/fonts/SourceHanSansSC-Normal.otf", 
         "assets/fonts/SourceHanSansSC-Normal-Subset.otf"),
    ]
    
    total_saved = 0
    
    for input_font, output_font in fonts:
        if not os.path.exists(input_font):
            print(f"\n警告: 文件不存在 - {input_font}")
            continue
        
        try:
            original_size = os.path.getsize(input_font)
            subset_font(input_font, output_font)
            new_size = os.path.getsize(output_font)
            total_saved += (original_size - new_size)
        except Exception as e:
            print(f"\n✗ 处理失败: {input_font}")
            print(f"错误: {e}")
    
    print("\n" + "=" * 60)
    print(f"总共节省空间: {total_saved / 1024 / 1024:.2f} MB")
    print("=" * 60)
    
    print("\n下一步:")
    print("1. 将原字体文件重命名为备份")
    print("2. 将子集字体重命名为原文件名")
    print("3. 或者修改 pubspec.yaml 使用子集字体")

if __name__ == "__main__":
    main()
