# Model

This directory contains the PyTorch model for MNIST digit recognition and related files.

## Structure

- **model.py**: Contains the model architecture definition
- **train.py**: Script for training the model on the MNIST dataset
- **data/**: Directory for storing training data
- **saved_models/**: Directory for storing trained model weights

## Saved Models

The `saved_models` directory is used to store trained models.

After running the training script (`python model/train.py`), the best model will be saved as `saved_models/mnist_model.pth`.

Note: The actual model files (*.pth) are not tracked in Git due to their size. 