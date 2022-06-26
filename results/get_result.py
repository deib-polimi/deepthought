import numpy as np
import pandas as pd

columns = ['voters', 'propositions', 'accuracy', 'adv_control', 'prop_corrupted', 'target_corrupted', 'elapsed_time']
df = pd.read_csv('results_DeepThought.csv')
df = df.drop(0)
print (df)

print("\nCASE 1:")
case = df.loc[df['accuracy'] == 0.80].loc[df['adv_control'] == 0.0]
#print(case)
num = case.shape[0]
avg_corrupted = case['prop_corrupted'].sum()/num
std_corrupted = case['prop_corrupted'].std()
min_corrupted = case['prop_corrupted'].min()
max_corrupted = case['prop_corrupted'].max()
for i in range(4):
	print(columns[i],":", case.iloc[0][i], end=", ")
print('prop_corrupted_avg :', avg_corrupted, end=", ")
print('prop_corrupted_std : ', std_corrupted, end=", ")
print('prop_corrupted_min : ', min_corrupted, end=", ")
print('prop_corrupted_max : ', max_corrupted, end=", ")
print('num_test : ', num)

print("\nCASE 2:")
case = df.loc[df['accuracy'] == 0.80].loc[df['adv_control'] == 0.05]
#print(case)
num = case.shape[0]
avg_corrupted = case['prop_corrupted'].sum()/num
std_corrupted = case['prop_corrupted'].std()
min_corrupted = case['prop_corrupted'].min()
max_corrupted = case['prop_corrupted'].max()
for i in range(4):
	print(columns[i],":", case.iloc[0][i], end=", ")
print('prop_corrupted_avg :', avg_corrupted, end=", ")
print('prop_corrupted_std : ', std_corrupted, end=", ")
print('prop_corrupted_min : ', min_corrupted, end=", ")
print('prop_corrupted_max : ', max_corrupted, end=", ")
print('num_test : ', num)

print("\nCASE 3:")
case = df.loc[df['accuracy'] == 0.80].loc[df['adv_control'] == 0.25]
#print(case)
num = case.shape[0]
avg_corrupted = case['prop_corrupted'].sum()/num
std_corrupted = case['prop_corrupted'].std()
min_corrupted = case['prop_corrupted'].min()
max_corrupted = case['prop_corrupted'].max()
for i in range(4):
	print(columns[i],":", case.iloc[0][i], end=", ")
print('prop_corrupted_avg :', avg_corrupted, end=", ")
print('prop_corrupted_std : ', std_corrupted, end=", ")
print('prop_corrupted_min : ', min_corrupted, end=", ")
print('prop_corrupted_max : ', max_corrupted, end=", ")
print('num_test : ', num)

print("\nCASE 4:")
case = df.loc[df['accuracy'] == 0.95].loc[df['adv_control'] == 0.0]
#print(case)
num = case.shape[0]
avg_corrupted = case['prop_corrupted'].sum()/num
std_corrupted = case['prop_corrupted'].std()
min_corrupted = case['prop_corrupted'].min()
max_corrupted = case['prop_corrupted'].max()
for i in range(4):
	print(columns[i],":", case.iloc[0][i], end=", ")
print('prop_corrupted_avg :', avg_corrupted, end=", ")
print('prop_corrupted_std : ', std_corrupted, end=", ")
print('prop_corrupted_min : ', min_corrupted, end=", ")
print('prop_corrupted_max : ', max_corrupted, end=", ")
print('num_test : ', num)

print("\nCASE 5:")
case = df.loc[df['accuracy'] == 0.95].loc[df['adv_control'] == 0.05]
#print(case)
num = case.shape[0]
avg_corrupted = case['prop_corrupted'].sum()/num
std_corrupted = case['prop_corrupted'].std()
min_corrupted = case['prop_corrupted'].min()
max_corrupted = case['prop_corrupted'].max()
for i in range(4):
	print(columns[i],":", case.iloc[0][i], end=", ")
print('prop_corrupted_avg :', avg_corrupted, end=", ")
print('prop_corrupted_std : ', std_corrupted, end=", ")
print('prop_corrupted_min : ', min_corrupted, end=", ")
print('prop_corrupted_max : ', max_corrupted, end=", ")
print('num_test : ', num)

print("\nCASE 6:")
case = df.loc[df['accuracy'] == 0.95].loc[df['adv_control'] == 0.25]
#print(case)
num = case.shape[0]
avg_corrupted = case['prop_corrupted'].sum()/num
std_corrupted = case['prop_corrupted'].std()
min_corrupted = case['prop_corrupted'].min()
max_corrupted = case['prop_corrupted'].max()
for i in range(4):
	print(columns[i],":", case.iloc[0][i], end=", ")
print('prop_corrupted_avg :', avg_corrupted, end=", ")
print('prop_corrupted_std : ', std_corrupted, end=", ")
print('prop_corrupted_min : ', min_corrupted, end=", ")
print('prop_corrupted_max : ', max_corrupted, end=", ")
print('num_test : ', num)
