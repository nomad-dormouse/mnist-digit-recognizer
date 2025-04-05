# Model

This directory contains the PyTorch model for MNIST digit recognition and related files.

## Structure

- **model.py**: Contains the model architecture definition
- **train.py**: Script for training the model on the MNIST dataset
- **data/**: Directory for storing the MNIST dataset
- **trained_model.pth**: The trained model file

## Model File

After running the training script (`python model/train.py`), the best model will be saved as `trained_model.pth`.

Note: The actual model file (*.pth) is not tracked in Git due to its size. 