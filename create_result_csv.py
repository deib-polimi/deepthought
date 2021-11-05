import csv

header = ['voters', 'propositions', 'accuracy', 'adv_control', 'prop_corrupted', 'target_corrupted', 'elapsed_time']

data = [100, 100, 0.95, 0.25, 0, 0, 9387.19]

with open('results.csv', 'w', encoding='UTF8', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(header)
    writer.writerow(data)
