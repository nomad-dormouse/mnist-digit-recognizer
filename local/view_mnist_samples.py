#!/usr/bin/env python3
"""MNIST dataset visualization tool - Shows random samples in a 5x5 grid"""
import os
import webbrowser
import numpy as np
import torch
import torchvision
import plotly.graph_objects as go
import plotly.subplots as sp

# File settings
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "mnist_samples.html")
GRID_SIZE = 5

# Load MNIST dataset
print("Loading MNIST dataset...")
mnist_train = torchvision.datasets.MNIST(
    root=os.path.join(os.path.dirname(SCRIPT_DIR), 'model', 'data'), 
    train=True, 
    download=True, 
    transform=torchvision.transforms.ToTensor()
)

# Create visualization
fig = sp.make_subplots(rows=GRID_SIZE, cols=GRID_SIZE)
digit_labels = []

# Generate grid of images
for i in range(GRID_SIZE):
    for j in range(GRID_SIZE):
        idx = np.random.randint(len(mnist_train))
        img, label = mnist_train[idx]
        digit_labels.append(label)
        
        fig.add_trace(
            go.Heatmap(
                z=img.numpy()[0],
                colorscale='gray_r',
                showscale=False,
                hoverinfo='none',
                zmin=0, zmax=1
            ),
            row=i+1, col=j+1
        )

# Configure layout
fig.update_layout(
    title_text="MNIST Dataset Sample Images",
    height=800, width=1000,
    showlegend=False,
)

# Configure axes
for i in range(GRID_SIZE * GRID_SIZE):
    row, col = i//GRID_SIZE+1, i%GRID_SIZE+1
    fig.update_xaxes(showticklabels=False, showgrid=False, zeroline=False, row=row, col=col)
    fig.update_yaxes(showticklabels=False, showgrid=False, zeroline=False, row=row, col=col)
    fig.update_layout(**{
        f'xaxis{i+1}_title': f'Label: {digit_labels[i]}',
        f'xaxis{i+1}_title_font': {'size': 16, 'color': 'blue'},
    })

# Save and display
fig.write_html(OUTPUT_FILE)
print(f"Opening {OUTPUT_FILE} in your default browser...")
webbrowser.open('file://' + os.path.abspath(OUTPUT_FILE))

# Display info
print(f"\nMNIST Dataset Information:")
print(f"- Training samples: {len(mnist_train)}")
print(f"- Image dimensions: 28x28 pixels (grayscale)")
print(f"- Labels: Digits 0-9")
print(f"- Visualization saved to: {OUTPUT_FILE}") 