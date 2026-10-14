from pathlib import Path
import argparse
import csv
import json
import re
import unicodedata
import math
import openpyxl

ROOT = Path(__file__).resolve().parents[1]

def norm(value):
    value = unicodedata.normalize('NFKD', str(value))
    value = ''.join(c for c in value if not unicodedata.combining(c)).lower()
    return re.sub(r'[^a-z0-9]+', '_', value).strip('_')

def key(department, district):
    return str(department).strip(), str(district).strip()

def table(book, sheet, header=1):
    rows = list(book[sheet].values)
    names = list(rows[header - 1])
    while names and names[-1] is None:
        names.pop()
    assert all(names) and len(names) == len(set(names)), (sheet, names)
    result = []
    for row in rows[header:]:
        if any(x is not None for x in row):
            assert not any(x is not None for x in row[len(names):]), sheet
            result.append(dict(zip(names, list(row) + [None] * (len(names) - len(row)))))
    return result

def unique(rows, columns):
    index = {}
    for row in rows:
        k = tuple(row[c] for c in columns)
        assert all(v is not None for v in k), (columns, k)
        assert k not in index, ('Clave duplicada', columns, k)
        index[k] = row
    return index

def write_csv(path, rows, columns=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    columns = columns or list(rows[0])
    with path.open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)
    with path.open(encoding='utf-8', newline='') as f:
        read = list(csv.DictReader(f))
    assert len(read) == len(rows)
    for old, new in zip(rows, read):
        assert all(new[c] == ('' if old[c] is None else str(old[c])) for c in columns)

def prepare(source):
    source = Path(source)
    files = sorted(source.glob('*.xlsx'))
    assert len(files) == 5, 'Se requieren los cinco adjuntos originales.'
    books = {p.name[:2]: openpyxl.load_workbook(p, read_only=True, data_only=True) for p in files}
    assert set(books) == {'01', '02', '03', '04', '05'}
    out = ROOT / 'datos' / 'bases'
    outputs = {}
    sheet_map = {'m1_corte_2022': '10 M1 corte 2022', 'm2_panel': '20 M2 panel',
                 'm3_abandono': '30 M3 abandono', 'm3_retencion': '31 M3 retención',
                 'm3_educacion_inicial': '32 M3 educación inicial', 'cruce_distritos': '04 Cruce de distritos'}
    rename = {'ipm_h': 'ipm_h_percent'}
    dictionary = []
    for name, sheet in sheet_map.items():
        original = table(books['01'], sheet)
        mapping = {c: rename.get(norm(c), norm(c)) for c in original[0]}
        assert len(set(mapping.values())) == len(mapping)
        outputs[name] = [{mapping[c]: v for c, v in row.items()} for row in original]
        for c, target in mapping.items():
            dictionary.append({'base': name.replace('_', '-'), 'variable': target, 'etiqueta': c,
                               'fuente': files[0].name, 'hoja': sheet, 'transformacion': 'Valor original; nombre normalizado'})
        for a, b in zip(original, outputs[name]):
            assert all(a[c] == b[mapping[c]] for c in mapping)
    m1, m2, m3 = [outputs[k] for k in ['m1_corte_2022', 'm2_panel', 'm3_abandono']]
    m1_index = unique(m1, ['clave_distrito'])
    unique(m2, ['clave_distrito', 'ano'])
    cruce = outputs['cruce_distritos']
    geo = unique(cruce, ['departamento_original', 'distrito_original'])
    for row in cruce:
        row['clave_distrito'] = f"{int(row['codigo_departamento'])}-{int(row['codigo_distrito'])}"
        canonical = m1_index[(row['clave_distrito'],)]
        assert key(row['departamento_canonico'], row['distrito_canonico']) == key(canonical['departamento'], canonical['distrito'])
    assert {r['clave_distrito'] for r in cruce} == {r['clave_distrito'] for r in m1}
    for row in m3:
        linked = geo[key(row['departamento'], row['distrito'])]
        row['clave_distrito'] = linked['clave_distrito']
    unique(m3, ['clave_distrito', 'ciclo', 'zona', 'sector', 'sexo', 'periodo'])
    for row in outputs['m3_retencion']:
        row['mayor_que_1'] = 'Sí' if row['valor_de_retencion'] > 1 else 'No'
    for name, cols in [('m3_retencion', ['indicador', 'departamento', 'zona', 'sexo', 'ano']),
                       ('m3_educacion_inicial', ['departamento', 'ano'])]:
        unique(outputs[name], cols)
    links = table(books['05'], 'District Links', 4)
    link_index = unique(links, ['Paper 1 department', 'Paper 1 district'])
    enriched = table(books['05'], 'Enriched Data', 4)
    enriched_index = unique(enriched, ['District ID'])
    assert set(enriched_index) == set(m1_index)
    poverty = []
    department = 'Asunción'
    for i, row in enumerate(books['03']['Distrital'].values, 1):
        row = tuple(row) + (None,) * 8
        if i < 7 or row[1] is None:
            continue
        if isinstance(row[2], (int, float)):
            poverty.append(dict(departamento=department, distrito=str(row[1]).strip(), fila_fuente=i,
                                pobreza_monetaria_ine_2022=row[2], pobreza_monetaria_limite_inferior=row[3],
                                pobreza_monetaria_limite_superior=row[4], pobreza_monetaria_rango=row[5]))
        elif row[1] in {r['INE poverty department'] for r in links}:
            department = row[1]
    nbi = []
    department = 'Asunción'
    nbi_names = ['hogares_ine_2022', 'nbi_al_menos_una_2022', 'nbi_vivienda_2022',
                 'nbi_sanitaria_2022', 'nbi_educacion_2022', 'nbi_subsistencia_2022']
    nbi_aggregates = []
    for i, row in enumerate(books['04']['NBI'].values, 1):
        row = tuple(row) + (None,) * 8
        if not isinstance(row[2], (int, float)):
            continue
        label = str(row[1]).strip()
        if label.startswith('Departamento '):
            department = label.removeprefix('Departamento ')
        values = dict(zip(nbi_names, [row[2]] + [x / 100 for x in row[3:8]]))
        record = dict(departamento='Paraguay' if label == 'Total País' else department,
                      distrito=label, fila_fuente=i, **values)
        if label == 'Total País' or label.startswith('Departamento '):
            nbi_aggregates.append(record)
        else:
            nbi.append(record)
    pindex = unique(poverty, ['departamento', 'distrito'])
    nindex = unique(nbi, ['departamento', 'distrito'])
    old_columns = {'Attrition proxy': 'desgranamiento', 'Existing poverty proportion': 'pobreza',
                   'Existing multidimensional poverty headcount': 'ipm_h_percent',
                   'Existing nonattendance proportion': 'inasistencia', 'Existing overage proportion': 'sobreedad',
                   'Existing minimum achievement proportion': 'logro_minimo', 'Existing child labour proportion': 'trabajo_infantil'}
    new_columns = dict(zip(['INE monetary poverty incidence', 'INE monetary poverty lower limit',
                           'INE monetary poverty upper limit', 'INE monetary poverty range',
                           'INE total households', 'INE households with at least one NBI', 'INE NBI housing quality',
                           'INE NBI sanitary infrastructure', 'INE NBI access to education', 'INE NBI subsistence capacity'],
                          ['pobreza_monetaria_ine_2022', 'pobreza_monetaria_limite_inferior',
                           'pobreza_monetaria_limite_superior', 'pobreza_monetaria_rango'] + nbi_names))
    reconciliation = []
    mismatches = []
    for row in m1:
        supplied = enriched_index[(row['clave_distrito'],)]
        assert key(supplied['Department'], supplied['District']) == key(row['departamento'], row['distrito'])
        for old, current in old_columns.items():
            assert supplied[old] == row[current], (row['clave_distrito'], old)
        link = link_index[key(row['departamento'], row['distrito'])]
        p = pindex[key(link['INE poverty department'], link['INE poverty district'])]
        n = nindex[key(link['INE NBI department'], link['INE NBI district'])]
        row.update({c: p[c] for c in list(new_columns.values())[:4]})
        row.update({c: n[c] for c in nbi_names})
        row['fila_fuente_pobreza_ine'] = p['fila_fuente']
        row['fila_fuente_nbi_ine'] = n['fila_fuente']
        row['pobreza_estimacion_sintetica'] = 'Sí' if p['departamento'] in ['Alto Paraguay', 'Boquerón'] else 'No'
        for old, current in new_columns.items():
            a, b = supplied[old], row[current]
            same = math.isclose(a, b, rel_tol=0, abs_tol=1e-12) if isinstance(a, (float, int)) else a == b
            if not same:
                mismatches.append({'clave_distrito': row['clave_distrito'], 'variable': current, 'adjunto_enriquecido': a, 'fuente_ine': b})
        reconciliation.append(dict(clave_distrito=row['clave_distrito'], departamento=row['departamento'], distrito=row['distrito'],
                                   departamento_pobreza=p['departamento'], distrito_pobreza=p['distrito'], fila_pobreza=p['fila_fuente'],
                                   departamento_nbi=n['departamento'], distrito_nbi=n['distrito'], fila_nbi=n['fila_fuente']))
    assert len({(r['departamento_pobreza'], r['distrito_pobreza']) for r in reconciliation}) == len(m1)
    assert len({(r['departamento_nbi'], r['distrito_nbi']) for r in reconciliation}) == len(m1)
    paired = [r for r in m2 if r['ano'] == 2022]
    common = set(paired[0]) & set(m1[0])
    assert len(paired) == len(m1)
    for row in paired:
        assert all(row[c] == m1_index[(row['clave_distrito'],)][c] for c in common)
    for row in m1 + m2:
        assert row['matricula_primer_grado'] > 0
        assert abs(row['retencion_g9_g1'] - row['matricula_noveno_grado'] / row['matricula_primer_grado']) <= 5.00001e-6
        assert abs(row['desgranamiento'] - max(0, 1-row['retencion_g9_g1'])) < 1e-12
        assert row['privacion_educativa_relativa'] == int(row['retencion_g9_g1'] < row['percentil_25_departamental'])
    for row in m1:
        assert 0 <= row['pobreza_monetaria_limite_inferior'] <= row['pobreza_monetaria_ine_2022'] <= row['pobreza_monetaria_limite_superior'] <= 1
        assert all(0 <= row[c] <= 1 for c in nbi_names[1:])
    outputs['ine_pobreza_distrital_2022'] = poverty
    outputs['ine_nbi_distrital_2022'] = nbi
    outputs['ine_nbi_agregados_2022'] = nbi_aggregates
    outputs['enlaces_ine_2022'] = reconciliation
    barrios = []
    for i, row in enumerate(books['03']['Asunción'].values, 1):
        row = tuple(row) + (None,) * 6
        if i >= 7 and row[1] is not None and (isinstance(row[2], (int, float)) or (i >= 9 and i <= 76)):
            barrios.append(dict(fila_fuente=i, nivel_geografico='Distrito' if i == 7 else 'Barrio',
                                barrio=row[1], incidencia=row[2], limite_inferior=row[3], limite_superior=row[4], rango=row[5]))
    outputs['ine_pobreza_asuncion_barrios'] = barrios
    for name, rows in outputs.items():
        filename = name.replace('_', '-') + '.csv'
        write_csv(out / filename, rows)
    extra_defs = {
        'clave_distrito': 'Código departamento-código distrito; enlace exacto con el cruce suministrado.',
        'mayor_que_1': 'Sí si valor_de_retencion > 1; valor original conservado.',
        'pobreza_monetaria_ine_2022': 'Proporción distrital. Censo 2022 y EPHC 2023, según nota de la fuente.',
        'pobreza_monetaria_limite_inferior': 'Límite inferior publicado, proporción; no se supone nivel de confianza.',
        'pobreza_monetaria_limite_superior': 'Límite superior publicado, proporción; no se supone nivel de confianza.',
        'pobreza_monetaria_rango': 'Categoría publicada en porcentaje.',
        'hogares_ine_2022': 'Número de hogares censales.',
        'pobreza_estimacion_sintetica': 'Sí para Boquerón y Alto Paraguay según nota del INE.',
        'fila_fuente_pobreza_ine': 'Fila Excel de Distrital en fuente monetaria.',
        'fila_fuente_nbi_ine': 'Fila Excel de NBI en fuente censal.'}
    for name in nbi_names[1:]:
        extra_defs[name] = 'Proporción de hogares; porcentaje publicado dividido por 100.'
    known = {(r['base'], r['variable']) for r in dictionary}
    for name in sheet_map:
        for col in outputs[name][0]:
            if (name.replace('_', '-'), col) not in known:
                dictionary.append(dict(base=name.replace('_', '-'), variable=col, etiqueta=col, fuente='INE 2022 / cruce adjunto', hoja='', transformacion=extra_defs[col]))
    for row in dictionary:
        v = row['variable']
        row['uso'] = 'Identificación, trazabilidad o variable original'
        row['unidad'] = 'Según etiqueta original'
        if v in ['ipm_h_percent', 'pobreza', 'inasistencia', 'sobreedad', 'logro_minimo', 'trabajo_infantil']:
            row['uso'] = 'Contexto departamental; repetido entre distritos'
            row['unidad'] = 'Porcentaje' if v == 'ipm_h_percent' else 'Proporción'
        if v.startswith('nbi_') or v in ['pobreza_monetaria_ine_2022', 'pobreza_monetaria_limite_inferior', 'pobreza_monetaria_limite_superior']:
            row['uso'] = 'Medida distrital INE'
            row['unidad'] = 'Proporción'
        if v == 'privacion_educativa_relativa':
            row['uso'] = 'Descripción relativa; excluida como predictor del desgranamiento'
            row['unidad'] = 'Binaria 0/1'
        if v == 'hogares_ine_2022':
            row['unidad'] = 'Hogares'
    write_csv(ROOT / 'datos' / 'diccionario-de-variables.csv', dictionary)
    assert not mismatches, 'Diferencias entre los indicadores INE y el corte enriquecido.'
    print(json.dumps({name.replace('_', '-'): len(rows) for name, rows in outputs.items()}, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=ROOT / 'datos' / 'fuentes')
    args = parser.parse_args()
    prepare(args.source)
