#!/usr/bin/env python3
"""Fill the supplied university diary format with verified Practice_R results."""
from pathlib import Path
import csv
from datetime import datetime, timezone

from docx import Document
from docx.shared import Cm, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'reports/Practice_R_Diary_Katsap_602.docx'
doc = Document(ROOT / 'reports/templates/practice-diary-template.docx')
# Keep the supplied A4 section geometry and replace the illustrative form content.
for child in list(doc.element.body):
    if child.tag != qn('w:sectPr'):
        doc.element.body.remove(child)
for style in doc.styles:
    if style.type in (1, 2):
        style.font.name = 'Times New Roman'
        style.font.color.rgb = RGBColor(0, 0, 0)
        style.font.underline = False
        for node in list(style.element.iter(qn('w:pBdr'))):
            node.getparent().remove(node)
normal = doc.styles['Normal']
normal.font.size = Pt(12)
normal.paragraph_format.line_spacing = 1.05
normal.paragraph_format.space_after = Pt(5)
normal.paragraph_format.widow_control = True
for name in ['Title', 'Heading 1', 'Heading 2']:
    s = doc.styles[name]
    s.font.size = Pt(14)
    s.font.bold = True
    s.paragraph_format.space_before = Pt(0)
    s.paragraph_format.space_after = Pt(7)

def para(text='', *, size=12, bold=False, center=False, after=5, before=0,
         style=None, page=False, keep=False, align=None):
    p = doc.add_paragraph(style=style)
    p.alignment = (WD_ALIGN_PARAGRAPH.CENTER if center else
                   align if align is not None else WD_ALIGN_PARAGRAPH.JUSTIFY)
    f = p.paragraph_format
    f.space_before, f.space_after = Pt(before), Pt(after)
    f.keep_with_next = keep
    f.page_break_before = page
    r = p.add_run(text)
    r.bold, r.font.size, r.font.name = bold, Pt(size), 'Times New Roman'
    r.font.color.rgb = RGBColor(0, 0, 0)
    r.font.underline = False
    return p

def title(text, page=False):
    return para(text, size=14, bold=True, center=True, style='Title', page=page, keep=True)

def heading(text, page=False):
    return para(text, size=13, bold=True, style='Heading 1', page=page, keep=True,
                align=WD_ALIGN_PARAGRAPH.LEFT, before=7)

def table(headers, rows, widths, size=11.5, left=(1,)):
    t = doc.add_table(rows=1, cols=len(headers))
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    t.autofit = False
    for col, width in zip(t.columns, widths):
        col.width = Cm(width)
    for vals in [headers] + rows:
        row = t.rows[0] if vals is headers else t.add_row()
        for j, (cell, text, width) in enumerate(zip(row.cells, vals, widths)):
            cell.width = Cm(width)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            p = cell.paragraphs[0]
            p.paragraph_format.space_after = Pt(0)
            p.paragraph_format.line_spacing = 1.0
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT if j in left and vals is not headers else WD_ALIGN_PARAGRAPH.CENTER
            r = p.add_run(str(text))
            r.font.name = 'Times New Roman'
            r.font.size = Pt(size)
            r.font.color.rgb = RGBColor(0, 0, 0)
            r.bold = vals is headers
            pr = cell._tc.get_or_add_tcPr()
            margins = OxmlElement('w:tcMar')
            for edge in ['top', 'left', 'bottom', 'right']:
                n = OxmlElement('w:' + edge)
                n.set(qn('w:w'), '65' if edge in ('top', 'bottom') else '80')
                n.set(qn('w:type'), 'dxa')
                margins.append(n)
            pr.append(margins)
            if vals is headers:
                sh = OxmlElement('w:shd'); sh.set(qn('w:fill'), 'F2F2F2'); pr.append(sh)
        trpr = row._tr.get_or_add_trPr()
        trpr.append(OxmlElement('w:cantSplit'))
    t.rows[0]._tr.get_or_add_trPr().append(OxmlElement('w:tblHeader'))
    borders = OxmlElement('w:tblBorders')
    for edge in ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']:
        n = OxmlElement('w:' + edge)
        n.set(qn('w:val'), 'single'); n.set(qn('w:sz'), '5'); n.set(qn('w:color'), '808080')
        borders.append(n)
    t._tbl.tblPr.append(borders)
    para('', size=2, after=0)
    return t

def picture(path, caption, width=16.4, caption_after=12):
    p = doc.add_paragraph()
    p.paragraph_format.keep_with_next = True
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(str(ROOT / path), width=Cm(width))
    para(caption, size=11, center=True, after=caption_after)

NAME = 'Кацап Владислав Геннадійович'
LEADER = 'Унгурян Галина Михайлівна'
DEGREE = 'кандидат фізико-математичних наук (доктор філософії), вчене звання — доцент'
FACULTY = 'Факультет математики та інформатики'
CHAIR = 'Кафедра прикладної математики та інформаційних технологій'
BASE = ('Загальнофакультетська спеціалізована науково-дослідна лабораторія '
        'з дослідження та розробки систем автоматизованого проектування '
        '«Development of CAD/CAM/CAE - systems»')
TOPIC = 'Прикладний статистичний аналіз даних із використанням мови програмування R'
PERIOD = '12–31.10.\n2026'

# Page 1: supplied diary form, with seven actual assignment stages.
para('Чернівецький національний університет імені Юрія Федьковича', center=True, after=6)
para(FACULTY, center=True, after=12)
title('ЩОДЕННИК\nВИРОБНИЧО-НАУКОВОЇ ПРАКТИКИ\nМАГІСТРАНТА')
para(NAME, center=True, bold=True, size=13, after=2)
para('602 група', center=True, after=8)
para('за період з «12» жовтня по «31» жовтня 2026 року', center=True, bold=True, after=8)
para('Місце практики: ' + BASE + '.', size=11.5, after=6)
para('Керівник: ' + LEADER + ', ' + DEGREE + '.', size=11.5, after=6)
para('Тема роботи: «' + TOPIC + '».', size=11.5, after=8)
diary = [
    'Ознайомлення із завданням практики. Підготовка програмного середовища та набору даних для статистичного аналізу.',
    'Дослідження основних характеристик даних із використанням методів описової статистики.',
    'Побудова графіків для наочного представлення даних. Аналіз особливостей розподілу досліджуваних показників.',
    'Дослідження взаємозв’язків між показниками за допомогою методів кореляційного аналізу.',
    'Побудова регресійної моделі для аналізу залежностей і прогнозування значень.',
    'Перевірка якості побудованої моделі та працездатності програми. Оцінювання отриманих результатів.',
    'Узагальнення результатів роботи та формулювання висновків. Підготовка звіту з графіками й скриншотами виконання програми.',
]
table(['Дата\n(період)', 'Вид виконаної роботи', 'Відмітка\nпро виконання'],
      [[PERIOD, f'{i}. {s}', 'Виконано'] for i,s in enumerate(diary,1)], [2.6,11.1,2.8], size=11)
para('Підпис магістранта __________________   В. Г. Кацап', size=11, before=5, after=5)
para('Підпис керівника ____________________   Г. М. Унгурян', size=11, after=5)
para('У щоденнику наведено роботи за період практики. Оцінку кожного етапу виставляє керівник.',
     size=9, after=0)

# Page 2: report identity and the template's five-column work register.
para(FACULTY, center=True, page=True, after=5)
para(CHAIR, center=True, after=12)
title('ЗВІТ')
para('про проходження виробничо-наукової практики магістранта', center=True, after=6)
para(NAME, center=True, bold=True, size=13, after=2)
para('602 група', center=True, after=10)
para('У період з «12» жовтня по «31» жовтня 2026 року проходив виробничо-наукову практику '
     'у загальнофакультетській спеціалізованій науково-дослідній лабораторії з дослідження '
     'та розробки систем автоматизованого проектування «Development of CAD/CAM/CAE - systems» '
     'факультету математики та інформатики.', size=11.5, after=8)
para('Керівник виробничо-наукової практики: ' + LEADER + ', ' + DEGREE + '.', size=11.5, after=8)
para('Тема: «' + TOPIC + '».', size=11.5, after=8)
heading('За період практики мною виконано такі види робіт')
work = [
    'Завантажив CSV через readr, перевірив пропуски й дублікати. Вилучив 42 неповні рядки; перевів одиниці температури та вітру.',
    'Обчислив сім описових показників для чотирьох числових змінних. Зберіг усі моди при однаковій частоті значень.',
    'Побудував гістограми, boxplot і діаграми розсіювання за допомогою ggplot2; позначив можливі викиди за правилом 1,5 IQR.',
    'Розрахував кореляції Пірсона та Спірмена для шести пар змінних; для Пірсона — довірчі інтервали й p-значення з BH-корекцією.',
    'Навчив множинну лінійну регресію на перших 88 записах за часом. Обчислив прогнози й 95 % прогнозні інтервали.',
    'Перевірив модель на останніх 23 записах. Дослідив значущість коефіцієнтів, залишки, VIF і відстань Кука.',
    'Виконав п’ять інтеграційних тестів. Підготував очищені дані, 15 таблиць CSV, 8 графіків, модель RDS і звіт зі скриншотами.',
]
table(['№', 'Зміст роботи', 'Ф-т', 'Дата\n(період)', 'Підпис\nвикладача'],
      [[str(i), s, 'ФМІ', PERIOD, ''] for i,s in enumerate(work,1)], [0.7,9.0,1.6,2.6,2.6], size=11)

# Page 3: results, reflection, and official fields from the example.
heading('Результати виконаної роботи', page=True)
para('Мною розроблено модуль analysis.R для імпорту й очищення даних, статистичних розрахунків, '
     'візуалізації та прогнозування. Роботу виконано мовою R у RStudio з пакетами readr, dplyr '
     'і ggplot2. Набір airquality містить щоденні спостереження якості повітря в Нью-Йорку '
     'за травень–вересень 1973 року.')
para('У 153 початкових записах виявлено 44 пропущені значення у 42 рядках; точних дублікатів '
     'і некоректних рядків не виявлено. Після очищення залишилося 111 спостережень. '
     'Середня концентрація озону становить 42,10\u00a0ppb, медіана — 31\u00a0ppb, стандартне відхилення — 33,28\u00a0ppb.')
para('Озон має додатний зв’язок із температурою (r = 0,6985) і сонячною радіацією '
     '(r = 0,3483) та від’ємний зі швидкістю вітру (r = −0,6125). Коефіцієнти трьох '
     'предикторів регресії статистично значущі на рівні 0,05. Ці залежності описують '
     'асоціації та не доводять причинного впливу.')
with (ROOT / 'results/tables/metrics.csv').open() as f:
    metrics = {r['metric']: r['value'] for r in csv.DictReader(f)}
def number(key):
    return f'{float(metrics[key]):.4f}'.replace('.', ',').replace('-', '−')
table(['Показник', 'Значення'], [
    ['Навчальна / тестова вибірка', '88 / 23 спостереження'],
    ['R² на навчальній вибірці', number('train_r_squared')],
    ['R² на тестовій вибірці', number('test_r_squared')],
    ['RMSE на тестовій вибірці', number('test_rmse') + ' ppb'],
    ['MAE на тестовій вибірці', number('test_mae') + ' ppb'],
], [11.5,5.0], size=11.5, left=(0,))
para('Навчальний R² показує, що модель пояснює близько 62 % варіації озону в навчальних даних. '
     'Від’ємний тестовий R² означає гірший результат порівняно з ретроспективним прогнозом '
     'середнім значенням самого тестового набору. Тест Шапіро–Вілка виявив відхилення залишків '
     'від нормальності (p = 0,0000563). Тому модель придатна для навчального дослідження '
     'залежностей, а її практичне застосування потребує нових даних і додаткової перевірки.')
heading('Відгуки магістранта щодо проведення і змісту практики')
para('Під час роботи я закріпив навички обробки даних мовою R та роботи в RStudio. '
     'Навчився поєднувати статистичні показники з графічним аналізом і перевіряти модель '
     'на окремій тестовій вибірці. Зіставлення навчального й тестового R² показало, '
     'що добрий опис навчальних даних не гарантує точного прогнозування. '
     'Подальшу роботу доцільно спрямувати на нелінійні залежності, сезонність і новіші спостереження.')
para('Дата оформлення: 04 листопада 2026 року', size=11.5, before=6)
para('Підпис магістранта ________________   Кацап Владислав Геннадійович', size=11.5)
para('Підпис керівника __________________   Унгурян Галина Михайлівна', size=11.5, after=8)
para('Затверджено на засіданні кафедри прикладної математики та інформаційних технологій.', size=11.5)
para('Протокол № ______ від «____» __________________ 2026 р.', size=11.5, after=0)

# Keep actual screenshots from the earlier verified run; do not fabricate IDE output.
heading('Додаток А Код програми в RStudio', page=True)
para('Основний файл analysis.R містить функцію run_analysis. На скриншоті показано '
     'поділ даних за часом на навчальну й тестову вибірки, навчання лінійної регресії '
     'та збереження її коефіцієнтів і моделі.')
picture('reports/screenshots/rstudio-code.png', 'Рисунок А.1 — Фрагмент робочого коду analysis.R у RStudio')
heading('Порядок запуску програми')
para('Відкрити Practice_R.Rproj у RStudio та виконати в консолі команду:', after=7)
p = para('source("analysis.R", encoding = "UTF-8")', size=11, after=9, align=WD_ALIGN_PARAGRAPH.LEFT)
p.runs[0].font.name = 'Courier New'
para('Команда завантажує весь файл, визначає функцію run_analysis і запускає аналіз '
     'в інтерактивній сесії RStudio. Для повторного запуску слід виконувати весь файл '
     'кнопкою Source. Програма послідовно виконує сім етапів аналізу та зберігає '
     'оброблені дані, таблиці, графіки й модель у відповідних каталогах проєкту.')
heading('Підготовлені матеріали')
para('Код — analysis.R; вхідні дані — data/raw/airquality.csv; очищені дані — '
     'data/processed/airquality_clean.csv. Статистичні таблиці збережено у results/tables/, '
     'графіки — у results/figures/, модель — у results/models/ozone_linear_model.rds.')
para('Повний технічний звіт із вісьмома графіками: reports/Practice_R_Report.docx '
     'і reports/Practice_R_Report.pdf.', size=11.5)

heading('Додаток Б Результати виконання програми', page=True)
para('Скриншот консолі RStudio відображає фактичні результати аналізу: обсяг очищених '
     'даних, розміри вибірок, навчальний і тестовий R² та похибки прогнозування.')
picture('reports/screenshots/rstudio-results.png', 'Рисунок Б.1 — Результати виконання analysis.R у консолі RStudio')
heading('Перевірки працездатності')
para('Успішно виконано п’ять інтеграційних перевірок: відхилення неправильної структури CSV; '
     'виявлення помилкових числових значень; відхилення набору з менш ніж 50 коректними '
     'записами; очищення тестових дублікатів, фізично некоректних значень і неможливих дат; '
     'відтворення прогнозів збереженою моделлю. Журнал перевірок — results/test-output.txt.')
para('Окремо виконано вісім перевірок середовища R, зокрема роботи з CSV, PNG, матрицями '
     'та компіляції розширень C, C++ і Fortran. Ці перевірки підтверджують працездатність '
     'середовища, але не є оцінкою точності статистичної моделі.')
heading('Джерела та відтворюваність')
para('Дані: datasets::airquality, документація пакета datasets у R. Методи: документація '
     'stats::lm, stats::cor.test, stats::predict.lm та stats::shapiro.test. '
     'Параметри середовища зафіксовано у results/session-info.txt та environment/conda-linux-64.lock.')
para('Репозиторій роботи:\nhttps://github.com/VladyslavGennadijovych/Practice_R',
     size=11.5, align=WD_ALIGN_PARAGRAPH.LEFT)

# Appendix C uses the original plots generated by analysis.R, without changing results.
heading('Додаток В Графічні результати статистичного аналізу', page=True)
para('Графіки побудовано за 111 очищеними спостереженнями. Гістограми показують '
     'форму розподілів, а діаграми розмаху — медіани, розкид значень і можливі викиди.',
     size=11.5, after=5)
picture('results/figures/histograms.png',
        'Рисунок В.1 — Гістограми розподілу досліджуваних показників', width=14.8, caption_after=5)
picture('results/figures/boxplots.png',
        'Рисунок В.2 — Діаграми розмаху досліджуваних показників', width=14.8, caption_after=0)

heading('Додаток В Взаємозв’язки між показниками', page=True)
para('Вищі значення озону пов’язані з вищою температурою та нижчою швидкістю вітру. '
     'Матриця містить коефіцієнти кореляції Пірсона; виявлені зв’язки не доводять причинності.',
     size=11.5, after=5)
picture('results/figures/scatterplots.png',
        'Рисунок В.3 — Зв’язок концентрації озону з іншими показниками', width=16.4, caption_after=5)
picture('results/figures/correlation_heatmap.png',
        'Рисунок В.4 — Кореляційна матриця досліджуваних показників', width=15.2, caption_after=0)

heading('Додаток В Оцінювання результатів прогнозування', page=True)
para('Модель перевірено на 23 відкладених спостереженнях, які не використовувалися '
     'для навчання. Графік зіставляє фактичну концентрацію озону з прогнозом моделі.',
     size=11.5, after=7)
picture('results/figures/test_observed_predicted.png',
        'Рисунок В.5 — Фактичні та прогнозовані значення озону на тестовій вибірці')
para('Пунктирна діагональ відповідає точному збігу прогнозу з фактичним значенням. '
     'Віддалення точок від цієї лінії показує похибки прогнозування. '
     'RMSE становить ' + number('test_rmse') + ' ppb, тестовий R² — ' + number('test_r_squared') + '.',
     size=11.5)
para('Від’ємний тестовий R² і помітні відхилення прогнозів обмежують практичне застосування '
     'моделі. Для підвищення її прогнозної якості потрібні додаткові дані та перевірка '
     'альтернативних моделей. Усі графіки збережено в каталозі results/figures/.', size=11.5)

doc.core_properties.title = 'Щоденник і звіт виробничо-наукової практики Кацапа Владислава Геннадійовича'
doc.core_properties.subject = TOPIC
doc.core_properties.author = NAME
doc.core_properties.last_modified_by = NAME
doc.core_properties.created = datetime(2026,11,4,tzinfo=timezone.utc)
doc.core_properties.modified = datetime(2026,11,4,tzinfo=timezone.utc)
doc.core_properties.comments = ''
doc.save(OUT)
print(OUT)
