#!/usr/bin/env python

import numpy as np
import matplotlib.pyplot as plt
import sys

def histogram(arr, bins1, title, pdf_file, cumulative=False):
    plt.clf()
    plt.hist(arr, bins=bins1, cumulative=cumulative, normed=True)
    plt.title(title)
    plt.xlabel("Value")
    plt.ylabel("Frequency")
    plt.savefig(pdf_file)
    

instance_losses = []

all_losses = []
all_mins = []
all_diffs = []
all_avg_diffs = []

for line in sys.stdin:
    line.rstrip('\n')
    if not line.strip():
        instance_losses.sort()
        all_mins.append(instance_losses[0])
        if len(instance_losses) > 1:
            diff = instance_losses[0] - instance_losses[1]
            all_diffs.append(diff)
            avg_diff = instance_losses[0] - (sum(instance_losses[1:len(instance_losses)]) / len(instance_losses))
            all_avg_diffs.append(avg_diff)
        else:
            all_diffs.append(-10)
            all_avg_diffs.append(-10)
        instance_losses = []
        continue
    all_losses.append(float(line))
    instance_losses.append(float(line))

histogram(all_losses, 50, "Histogram of VW losses", 'all_losses.hist.pdf', cumulative=True)
histogram(all_mins, 50, "Histogram of VW min losses", 'min_losses.hist.pdf', cumulative=True)
histogram(all_diffs, 50, "Histogram of VW differences between the min and the second smallest value", 'diff_losses.hist.pdf', cumulative=True)
histogram(all_avg_diffs, 50, "Histogram of VW differences between the min and the average of the rest", 'avg_diff_losses.hist.pdf', cumulative=True)
