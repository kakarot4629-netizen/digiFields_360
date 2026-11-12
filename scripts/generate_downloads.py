import os
import shutil
import re
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import parse_xml
from docx.oxml.ns import nsdecls

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=140, right=140):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(f'<w:tcMar {nsdecls("w")}><w:top w:w="{top}" w:type="dxa"/><w:bottom w:w="{bottom}" w:type="dxa"/><w:left w:w="{left}" w:type="dxa"/><w:right w:w="{right}" w:type="dxa"/></w:tcMar>')
    tcPr.append(tcMar)

def create_docx(md_path, docx_path):
    doc = docx.Document()
    
    # 0.75-inch margins
    for section in doc.sections:
        section.top_margin = Inches(0.75)
        section.bottom_margin = Inches(0.75)
        section.left_margin = Inches(0.75)
        section.right_margin = Inches(0.75)

    normal_style = doc.styles['Normal']
    normal_style.font.name = 'Calibri'
    normal_style.font.size = Pt(10.5)
    normal_style.font.color.rgb = RGBColor(0x2B, 0x2B, 0x2B)

    # Title
    title = doc.add_paragraph()
    r_title = title.add_run("digiField360.ai — Salesforce Edition\n")
    r_title.font.name = 'Arial'
    r_title.font.size = Pt(22)
    r_title.font.bold = True
    r_title.font.color.rgb = RGBColor(0x00, 0x48, 0x8F)
    
    sub = title.add_run("High-Level Field Service (FSL) Architecture, Implementation Status & Production Roadmap\n")
    sub.font.size = Pt(13)
    sub.font.bold = True
    sub.font.color.rgb = RGBColor(0x4A, 0x55, 0x68)

    meta = doc.add_paragraph()
    meta.paragraph_format.space_after = Pt(14)
    r_meta = meta.add_run("Document Version: 1.0 (Master Release)  |  Target GA: Q1 2027  |  Prepared For: Executive & Technical Stakeholders")
    r_meta.font.size = Pt(9.5)
    r_meta.font.italic = True
    r_meta.font.color.rgb = RGBColor(0x71, 0x80, 0x96)

    with open(md_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    in_table = False
    table_rows = []
    in_code = False
    code_lines = []

    def flush_table():
        nonlocal in_table, table_rows
        if not table_rows:
            in_table = False
            return
        
        num_cols = max(len(r) for r in table_rows)
        tbl = doc.add_table(rows=len(table_rows), cols=num_cols)
        tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
        tbl.autofit = True

        for i, row in enumerate(table_rows):
            is_header = (i == 0)
            for j in range(num_cols):
                cell = tbl.cell(i, j)
                val = row[j] if j < len(row) else ""
                cell.text = val.strip()
                cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
                set_cell_margins(cell, top=100, bottom=100, left=120, right=120)
                
                p = cell.paragraphs[0]
                p.paragraph_format.space_after = Pt(2)
                p.paragraph_format.space_before = Pt(2)
                
                if is_header:
                    set_cell_background(cell, "00488F")
                    for run in p.runs:
                        run.font.name = 'Arial'
                        run.font.size = Pt(9)
                        run.font.bold = True
                        run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
                else:
                    if i % 2 == 1:
                        set_cell_background(cell, "F7FAFC")
                    else:
                        set_cell_background(cell, "FFFFFF")
                    for run in p.runs:
                        run.font.name = 'Calibri'
                        run.font.size = Pt(8.5)
                        run.font.color.rgb = RGBColor(0x2D, 0x37, 0x48)

        sp = doc.add_paragraph()
        sp.paragraph_format.space_after = Pt(6)
        table_rows = []
        in_table = False

    def flush_code():
        nonlocal in_code, code_lines
        if not code_lines:
            in_code = False
            return
        
        tbl = doc.add_table(rows=1, cols=1)
        tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
        cell = tbl.cell(0, 0)
        set_cell_background(cell, "EDF2F7")
        set_cell_margins(cell, top=100, bottom=100, left=140, right=140)
        
        p = cell.paragraphs[0]
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after = Pt(2)
        run = p.add_run("\n".join(code_lines))
        run.font.name = 'Consolas'
        run.font.size = Pt(8)
        run.font.color.rgb = RGBColor(0x2D, 0x37, 0x48)
        
        doc.add_paragraph().paragraph_format.space_after = Pt(6)
        code_lines = []
        in_code = False

    idx = 0
    while idx < len(lines):
        line = lines[idx].rstrip('\n')
        
        if line.startswith('```'):
            if in_code:
                flush_code()
            else:
                if in_table:
                    flush_table()
                in_code = True
            idx += 1
            continue

        if in_code:
            code_lines.append(line)
            idx += 1
            continue

        # Check for table
        if line.strip().startswith('|') and line.strip().endswith('|'):
            if '---' in line:
                idx += 1
                continue
            cells = [c.strip() for c in line.strip()[1:-1].split('|')]
            clean_cells = []
            for c in cells:
                c = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', c)
                c = c.replace('**', '').replace('`', '')
                clean_cells.append(c)
            table_rows.append(clean_cells)
            in_table = True
            idx += 1
            continue
        else:
            if in_table:
                flush_table()

        stripped = line.strip()
        if not stripped:
            idx += 1
            continue

        if stripped.startswith('# '):
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(16)
            p.paragraph_format.space_after = Pt(6)
            run = p.add_run(stripped[2:])
            run.font.name = 'Arial'
            run.font.size = Pt(16)
            run.font.bold = True
            run.font.color.rgb = RGBColor(0x00, 0x48, 0x8F)
        elif stripped.startswith('## '):
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(14)
            p.paragraph_format.space_after = Pt(5)
            run = p.add_run(stripped[3:])
            run.font.name = 'Arial'
            run.font.size = Pt(13.5)
            run.font.bold = True
            run.font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)
        elif stripped.startswith('### '):
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(10)
            p.paragraph_format.space_after = Pt(4)
            run = p.add_run(stripped[4:])
            run.font.name = 'Arial'
            run.font.size = Pt(11.5)
            run.font.bold = True
            run.font.color.rgb = RGBColor(0x2B, 0x6C, 0xB0)
        elif stripped.startswith('> '):
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Inches(0.25)
            p.paragraph_format.space_after = Pt(4)
            run = p.add_run(stripped[2:].replace('**', ''))
            run.font.italic = True
            run.font.color.rgb = RGBColor(0x4A, 0x55, 0x68)
        elif stripped.startswith('- ') or stripped.startswith('* '):
            p = doc.add_paragraph(style='List Bullet')
            p.paragraph_format.space_after = Pt(3)
            text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', stripped[2:])
            parts = re.split(r'(\*\*.*?\*\*)', text)
            for part in parts:
                if part.startswith('**') and part.endswith('**'):
                    r = p.add_run(part[2:-2])
                    r.font.bold = True
                else:
                    p.add_run(part)
        else:
            p = doc.add_paragraph()
            p.paragraph_format.space_after = Pt(6)
            text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', stripped)
            parts = re.split(r'(\*\*.*?\*\*)', text)
            for part in parts:
                if part.startswith('**') and part.endswith('**'):
                    r = p.add_run(part[2:-2])
                    r.font.bold = True
                else:
                    p.add_run(part)

        idx += 1

    if in_table:
        flush_table()
    if in_code:
        flush_code()

    doc.save(docx_path)
    print(f"Generated DOCX: {docx_path}")

def create_html(md_path, html_path):
    with open(md_path, 'r', encoding='utf-8') as f:
        md_text = f.read()

    # Basic markdown to HTML converter
    lines = md_text.split('\n')
    html_lines = []
    in_table = False
    in_code = False
    table_rows = []

    def flush_tbl():
        nonlocal in_table, table_rows
        if not table_rows:
            in_table = False
            return
        out = '<div class="table-responsive"><table><thead><tr>'
        for cell in table_rows[0]:
            out += f'<th>{cell}</th>'
        out += '</tr></thead><tbody>'
        for row in table_rows[1:]:
            out += '<tr>'
            for cell in row:
                out += f'<td>{cell}</td>'
            out += '</tr>'
        out += '</tbody></table></div>'
        html_lines.append(out)
        table_rows = []
        in_table = False

    for line in lines:
        if line.startswith('```'):
            if in_code:
                html_lines.append('</code></pre>')
                in_code = False
            else:
                if in_table:
                    flush_tbl()
                lang = line[3:].strip()
                html_lines.append(f'<pre><code class="language-{lang}">')
                in_code = True
            continue

        if in_code:
            html_lines.append(line.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;'))
            continue

        if line.strip().startswith('|') and line.strip().endswith('|'):
            if '---' in line:
                continue
            cells = [c.strip() for c in line.strip()[1:-1].split('|')]
            clean_cells = []
            for c in cells:
                c = re.sub(r'\[([^\]]+)\]\(([^\)]+)\)', r'<a href="\2" target="_blank">\1</a>', c)
                c = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', c)
                c = re.sub(r'`([^`]+)`', r'<code>\1</code>', c)
                clean_cells.append(c)
            table_rows.append(clean_cells)
            in_table = True
            continue
        else:
            if in_table:
                flush_tbl()

        stripped = line.strip()
        if not stripped:
            continue

        if stripped.startswith('# '):
            html_lines.append(f'<h1>{stripped[2:]}</h1>')
        elif stripped.startswith('## '):
            html_lines.append(f'<h2>{stripped[3:]}</h2>')
        elif stripped.startswith('### '):
            html_lines.append(f'<h3>{stripped[4:]}</h3>')
        elif stripped.startswith('> '):
            text = stripped[2:]
            text = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', text)
            html_lines.append(f'<blockquote>{text}</blockquote>')
        elif stripped.startswith('- ') or stripped.startswith('* '):
            text = stripped[2:]
            text = re.sub(r'\[([^\]]+)\]\(([^\)]+)\)', r'<a href="\2" target="_blank">\1</a>', text)
            text = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', text)
            text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
            html_lines.append(f'<li>{text}</li>')
        elif stripped == '---':
            html_lines.append('<hr/>')
        else:
            text = stripped
            text = re.sub(r'\[([^\]]+)\]\(([^\)]+)\)', r'<a href="\2" target="_blank">\1</a>', text)
            text = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', text)
            text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
            html_lines.append(f'<p>{text}</p>')

    if in_table:
        flush_tbl()
    if in_code:
        html_lines.append('</code></pre>')

    body_content = '\n'.join(html_lines)

    html_template = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>digiField360 — FSL Architecture & Roadmap</title>
  <style>
    :root {{
      --primary: #00488F;
      --primary-light: #E8F0FE;
      --secondary: #0070D2;
      --text: #2D3748;
      --bg: #F8FAFC;
      --surface: #FFFFFF;
      --border: #E2E8F0;
    }}
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.6;
      padding: 30px 15px;
    }}
    .container {{
      max-width: 1000px;
      margin: 0 auto;
      background: var(--surface);
      padding: 40px 50px;
      border-radius: 12px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.06);
      border: 1px solid var(--border);
    }}
    .actions-bar {{
      display: flex;
      justify-content: flex-end;
      gap: 12px;
      margin-bottom: 24px;
      position: sticky;
      top: 15px;
      z-index: 100;
    }}
    .btn {{
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: var(--primary);
      color: #fff;
      padding: 10px 18px;
      font-size: 14px;
      font-weight: 600;
      border-radius: 8px;
      text-decoration: none;
      border: none;
      cursor: pointer;
      box-shadow: 0 2px 6px rgba(0,72,143,0.3);
      transition: all 0.2s;
    }}
    .btn:hover {{ background: #003366; transform: translateY(-1px); }}
    .btn-secondary {{ background: #4A5568; box-shadow: 0 2px 6px rgba(74,85,104,0.3); }}
    .btn-secondary:hover {{ background: #2D3748; }}
    h1 {{ color: var(--primary); font-size: 28px; margin-bottom: 12px; border-bottom: 3px solid var(--primary); padding-bottom: 10px; }}
    h2 {{ color: #1A365D; font-size: 22px; margin-top: 32px; margin-bottom: 14px; border-bottom: 1px solid var(--border); padding-bottom: 6px; }}
    h3 {{ color: #2B6CB0; font-size: 18px; margin-top: 24px; margin-bottom: 10px; }}
    p {{ margin-bottom: 14px; }}
    blockquote {{
      background: var(--primary-light);
      border-left: 4px solid var(--primary);
      padding: 12px 18px;
      border-radius: 0 8px 8px 0;
      margin: 18px 0;
      color: #2D3748;
      font-style: italic;
    }}
    .table-responsive {{
      overflow-x: auto;
      margin: 20px 0;
      border-radius: 8px;
      border: 1px solid var(--border);
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 13.5px;
      text-align: left;
    }}
    th {{
      background: var(--primary);
      color: #FFFFFF;
      padding: 11px 14px;
      font-weight: 600;
    }}
    td {{
      padding: 10px 14px;
      border-bottom: 1px solid var(--border);
      color: var(--text);
    }}
    tr:nth-child(even) {{ background: #F8FAFC; }}
    tr:hover {{ background: #EDF2F7; }}
    pre {{
      background: #1A202C;
      color: #E2E8F0;
      padding: 18px;
      border-radius: 8px;
      overflow-x: auto;
      font-family: Consolas, Monaco, monospace;
      font-size: 13px;
      margin: 18px 0;
    }}
    code {{
      background: #EDF2F7;
      color: #C53030;
      padding: 2px 6px;
      border-radius: 4px;
      font-size: 13px;
      font-family: Consolas, Monaco, monospace;
    }}
    pre code {{ background: transparent; color: inherit; padding: 0; }}
    li {{ margin-left: 24px; margin-bottom: 6px; }}
    hr {{ border: none; border-top: 1px solid var(--border); margin: 30px 0; }}
    a {{ color: var(--secondary); text-decoration: none; }}
    a:hover {{ text-decoration: underline; }}
    @media print {{
      body {{ background: #fff; padding: 0; }}
      .container {{ box-shadow: none; border: none; padding: 0; width: 100%; max-width: 100%; }}
      .actions-bar {{ display: none; }}
    }}
  </style>
</head>
<body>
  <div class="container">
    <div class="actions-bar">
      <button class="btn" onclick="window.print()">🖨️ Print / Save as PDF</button>
      <a class="btn btn-secondary" href="digiField360_FSL_Implementation_Status_and_Roadmap.docx" download>📄 Download Word (.docx)</a>
    </div>
    {body_content}
  </div>
</body>
</html>"""

    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(html_template)
    print(f"Generated HTML: {html_path}")

def process_document(md_source, base_name, downloads_dir):
    docs_dir = 'docs'
    docx_file = os.path.join(docs_dir, f'{base_name}.docx')
    html_file = os.path.join(docs_dir, f'{base_name}.html')
    
    create_docx(md_source, docx_file)
    create_html(md_source, html_file)

    if os.path.exists(downloads_dir):
        dl_docx = os.path.join(downloads_dir, f'{base_name}.docx')
        dl_html = os.path.join(downloads_dir, f'{base_name}.html')
        dl_md = os.path.join(downloads_dir, f'{base_name}.md')

        for src, dst in [(docx_file, dl_docx), (html_file, dl_html), (md_source, dl_md)]:
            try:
                shutil.copyfile(src, dst)
                print(f"   -> Copied to {dst}")
            except PermissionError:
                alt_dst = dst.replace('.docx', '_v2.docx')
                try:
                    shutil.copyfile(src, alt_dst)
                    print(f"   -> File open in Word; copied to {alt_dst}")
                except Exception as e:
                    print(f"   -> Notice: {dst} is open in another app: {e}")
            except Exception as e:
                print(f"   -> Notice: Could not copy {dst}: {e}")
        print(f"[SUCCESS] Processed {base_name}")

def main():
    downloads_dir = os.path.expanduser('~/Downloads')
    
    # 1. FSL Roadmap
    process_document(
        'docs/FSL_IMPLEMENTATION_STATUS_AND_ROADMAP.md',
        'digiField360_FSL_Implementation_Status_and_Roadmap',
        downloads_dir
    )

    # 2. Sprint Documentation (Last 12 Days)
    process_document(
        'docs/SPRINT_DOCUMENTATION_LAST_12_DAYS.md',
        'digiField360_Sprint_Documentation_Last_12_Days',
        downloads_dir
    )

if __name__ == '__main__':
    main()
