import pandas as pd
import pickle
import re

# Glycans by taxonomic levels
df_species = pd.read_csv('pydata/glyco_targets_species_seq_all_V2clean.csv')
df_species.domain = [k.strip() for k in df_species.domain.values.tolist()]
df_species.kingdom = [k.strip() for k in df_species.kingdom.values.tolist()]
df_species.phylum = [k.strip() for k in df_species.phylum.values.tolist()]
df_species['class'] = [k.strip() for k in df_species['class'].values.tolist()]
df_species.order = [k.strip() for k in df_species.order.values.tolist()]
df_species.family = [k.strip() for k in df_species.family.values.tolist()]
df_species.genus = [k.strip() for k in df_species.genus.values.tolist()]
df_species.target = [str(k) for k in df_species.target.values.tolist()]

# Lists of possible bonds and sugars
with open('pydata/all_bonds.pkl','rb') as file:
    all_bonds = pickle.load(file)
    
with open('pydata/all_sugars.pkl','rb') as file:
    all_sugars = pickle.load(file)
    
def find_isomorphs(glycan):
  """finds glycan isomorphs if possible"""
  out_list = [glycan]
  
  #starting branch swap
  if '[' in glycan and glycan.index('[')>0 and not bool(re.search('\[[^\]]+\[', glycan)):
    glycan2 = re.sub('^(.*?)\[(.*?)\]', r'\2[\1]', glycan, 1)
    out_list.append(glycan2)
  
  #double branch swap
  temp = []
  for k in out_list:
    if '][' in k:
      glycan3 = re.sub('(\[.*?\])(\[.*?\])', r'\2\1', k)
      temp.append(glycan3)
    
  #starting branch swap2
  temp2 = []
  for k in temp:
    if '[' in k and k.index('[')>0 and not bool(re.search('\[[^\]]+\[', k)):
      glycan4 = re.sub('^(.*?)\[(.*?)\]', r'\2[\1]', k, 1)
      temp2.append(glycan4)
  return list(set(out_list+temp+temp2))

def link_find(s):
  """extracts disaccharide motifs from glycan"""  
  ss = find_isomorphs(s)
  coll = []
  for iso in ss:
    b_re = re.sub('\[[^\]]+\]', '', iso)
  for i in [iso, b_re]:
    b = i.split('(')
  b = [k.split(')') for k in b]
  b = [item for sublist in b for item in sublist]
  b = ['*'.join(b[i:i+3]) for i in range(0, len(b)-2, 2)]
  b = [k for k in b if (re.search('\*\[', k) is None and re.search('\*\]\[', k) is None)]
  b = [k.strip('[') for k in b]
  b = [k.strip(']') for k in b]
  b = [k.replace('[', '') for k in b]
  b = [k.replace(']', '') for k in b]
  coll += b
  return list(set(coll))
