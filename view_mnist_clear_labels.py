#!/usr/bin/env python3
import torch
import torchvision
import plotly.graph_objects as go
import numpy as np
import webbrowser
import os
from torchvision import datasets, transforms

# Load MNIST dataset
transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.1307,), (0.3081,))
])

# Download and load the training data
mnist_train = datasets.MNIST(root='./data', train=True, download=True, transform=transform)

# Get 25 random samples from the dataset
samples = []
labels = []
for _ in range(25):
    idx = np.random.randint(0, len(mnist_train))
    img, label = mnist_train[idx]
    samples.append(img.numpy()[0])
    labels.append(label)

# Create a figure for each digit with a large label
figures = []
for i, (sample, label) in enumerate(zip(samples, labels)):
    fig = go.Figure()
    
    # Add the image
    fig.add_trace(
        go.Heatmap(
            z=sample,
            colorscale='gray',
            showscale=False,
        )
    )
    
    # Add a very clear title with the label
    fig.update_layout(
        title={
            'text': f'<b>Label: {label}</b>',
            'y':0.9,
            'x':0.5,
            'xanchor': 'center',
            'yanchor': 'top',
            'font': {'size': 24, 'color': 'blue', 'family': 'Arial, bold'}
        },
        width=300,
        height=350,
        margin=dict(l=20, r=20, t=60, b=20),
    )
    
    # Remove axis labels and ticks
    fig.update_xaxes(showticklabels=False, showgrid=False, zeroline=False)
    fig.update_yaxes(showticklabels=False, showgrid=False, zeroline=False)
    
    figures.append(fig)

# Create a grid of subplots using HTML
html_content = """
<!DOCTYPE html>
<html>
<head>
    <title>MNIST Dataset Samples</title>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        h1 {
            color: #333;
            text-align: center;
        }
        .grid-container {
            display: grid;
            grid-template-columns: repeat(5, 1fr);
            gap: 15px;
            margin: 20px auto;
            max-width: 1500px;
        }
        .grid-item {
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
            padding: 10px;
        }
        .info {
            margin: 20px auto;
            max-width: 600px;
            background-color: white;
            padding: 15px;
            border-radius: 8px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }
    </style>
</head>
<body>
    <h1>MNIST Dataset Sample Images</h1>
    <div class="grid-container">
"""

for i in range(25):
    html_content += f"""
        <div class="grid-item">
            <div id="fig{i}"></div>
        </div>
    """

html_content += """
    </div>
    <div class="info">
        <h2>MNIST Dataset Information</h2>
        <p><strong>Total training samples:</strong> 60,000</p>
        <p><strong>Image dimensions:</strong> 28x28 pixels (grayscale)</p>
        <p><strong>Labels:</strong> Digits from 0 to 9</p>
        <p><strong>Pixel values:</strong> Range from 0 (white) to 1 (black)</p>
    </div>
    <script>
"""

for i in range(25):
    fig_json = figures[i].to_json()
    html_content += f"""
        var fig{i} = {fig_json};
        Plotly.newPlot('fig{i}', fig{i}.data, fig{i}.layout);
    """

html_content += """
    </script>
</body>
</html>
"""

# File path
output_file = "mnist_samples_clear_labels.html"

# Write to HTML file
with open(output_file, "w") as f:
    f.write(html_content)

# Get the absolute file path
file_path = os.path.abspath(output_file)

# Open the HTML file in the default web browser
print(f"Opening {output_file} in your default browser...")
webbrowser.open('file://' + file_path)

print("MNIST dataset visualization complete!")
print("A random sample of 25 images has been displayed with Plotly.")
print(f"The visualization has been saved to '{output_file}'")

# Display dataset statistics
print("\nMNIST Dataset Information:")
print(f"Total training samples: {len(mnist_train)}")
print("Image dimensions: 28x28 pixels (grayscale)")
print("Labels: Digits from 0 to 9")
print("Each pixel value ranges from 0 (white) to 1 (black)") 