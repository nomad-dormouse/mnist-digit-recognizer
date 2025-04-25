import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
import os
import sys
from pathlib import Path


# Load environment variables, return processed configuration
def load_environment_variables():
    for var in ENV_VARS:
        ENV_VARS[var] = os.getenv(var)
        if ENV_VARS[var] is None:
            print(f"Error: Missing required environment variable: {var}")
            sys.exit(1)
    
    model_dir = Path(f"/{ENV_VARS['CONTAINER_WORKDIR_NAME']}/{ENV_VARS['TRAINED_MODEL_DIR_NAME']}")
    config = {
        'dataset': {
            'mean': float(ENV_VARS['MNIST_DATASET_MEAN']),
            'std': float(ENV_VARS['MNIST_DATASET_STD'])
        },
        'training': {
            'batch_size': int(ENV_VARS['MODEL_BATCH_SIZE']),
            'epochs': int(ENV_VARS['MODEL_EPOCHS']),
            'learning_rate': float(ENV_VARS['MODEL_LEARNING_RATE']),
            'momentum': float(ENV_VARS['MODEL_MOMENTUM'])
        },
        'paths': {
            'dataset': Path(f"/{ENV_VARS['CONTAINER_WORKDIR_NAME']}/{ENV_VARS['DATASET_DIR_NAME']}"),
            'model_weights': model_dir / ENV_VARS['TRAINED_MODEL_NAME'],
            'model_file': model_dir / ENV_VARS['MODEL_FILE_NAME']
        }
    }
    return config

# Setup required directories
def setup_directories(config):
    config['paths']['dataset'].parent.mkdir(parents=True, exist_ok=True)
    config['paths']['model_weights'].parent.mkdir(parents=True, exist_ok=True)

# Load and prepare MNIST datasets
def load_datasets(config):
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((config['dataset']['mean'],), (config['dataset']['std'],))
    ])
    
    train_dataset = datasets.MNIST(config['paths']['dataset'], train=True, download=True, transform=transform)
    test_dataset = datasets.MNIST(config['paths']['dataset'], train=False, download=True, transform=transform)
    
    train_loader = DataLoader(train_dataset, batch_size=config['training']['batch_size'], shuffle=True)
    test_loader = DataLoader(test_dataset, batch_size=config['training']['batch_size'], shuffle=False)
    
    return train_loader, test_loader

# Train the model for one epoch
def train_epoch(model, train_loader, optimizer, device, current_epoch):
    model.train()
    for batch_idx, (data, target) in enumerate(train_loader):
        data, target = data.to(device), target.to(device)
        optimizer.zero_grad()
        output = model(data)
        loss = nn.CrossEntropyLoss()(output, target)
        loss.backward()
        optimizer.step()
        
        if batch_idx % 100 == 0:
            progress = 100. * batch_idx / len(train_loader)
            print(f'Epoch {current_epoch}: {batch_idx * len(data)}/{len(train_loader.dataset)} '
                  f'({progress:.0f}%) Loss: {loss.item():.6f}')

# Evaluate the model on the test dataset
def evaluate_model(model, test_loader, device):
    model.eval()
    test_loss = 0
    correct = 0
    with torch.no_grad():
        for data, target in test_loader:
            data, target = data.to(device), target.to(device)
            output = model(data)
            test_loss += nn.CrossEntropyLoss(reduction='sum')(output, target).item()
            pred = output.argmax(dim=1, keepdim=True)
            correct += pred.eq(target.view_as(pred)).sum().item()

    test_loss /= len(test_loader.dataset)
    accuracy = 100. * correct / len(test_loader.dataset)
    print(f'Test set: Loss: {test_loss:.4f}, Accuracy: {correct}/{len(test_loader.dataset)} ({accuracy:.2f}%)')
    return accuracy

# Save both model weights and model definition file
def save_model(model, accuracy, config):
    model_dir = config['paths']['model_weights'].parent
    model_dir.mkdir(parents=True, exist_ok=True)

    torch.save(model.state_dict(), config['paths']['model_weights'])
    print(f"Model weights saved to {config['paths']['model_weights']} with accuracy: {accuracy:.2f}%")
    
    try:
        import shutil
        model_py_src = Path(current_dir) / config['paths']['model_file'].name
        model_py_dest = config['paths']['model_file']
        shutil.copy2(model_py_src, model_py_dest)
        print(f"Copied {model_py_src.name} to {model_py_dest}\n")
    except Exception as e:
        print(f"ERROR: Could not copy model definition file: {e}")
        sys.exit(1)

# Try to load existing trained model using saved model definition
def load_existing_model(config, device):
    model_dir = config['paths']['model_weights'].parent
    weights_path = config['paths']['model_weights']
    model_py_path = config['paths']['model_file']
    
    print(f"Checking for existing model files:")
    print(f"- Weights file: {weights_path}")
    print(f"- Model definition: {model_py_path}")
    
    if not weights_path.exists() or not model_py_path.exists():
        print("Missing required model files")
        return None
    
    try:
        sys.path.insert(0, str(model_dir))
        
        from model import MNISTModel
        
        model = MNISTModel().to(device)
        state_dict = torch.load(weights_path, map_location=device)
        model.load_state_dict(state_dict)
        
        print("Successfully loaded existing model")
        return model
        
    except Exception as e:
        print(f"Error loading existing model: {str(e)}")
        return None
    finally:
        if str(model_dir) in sys.path:
            sys.path.remove(str(model_dir))

# Train a new model from scratch
def train_model(config, device):
    print("Initializing new model for training...")
    model = MNISTModel().to(device)
    
    train_loader, test_loader = load_datasets(config)
    optimizer = optim.SGD(
        model.parameters(), 
        lr=config['training']['learning_rate'], 
        momentum=config['training']['momentum']
    )
    
    best_accuracy = 0.0
    
    print("Starting training...")
    for epoch in range(1, config['training']['epochs'] + 1):
        train_epoch(model, train_loader, optimizer, device, epoch)
        accuracy = evaluate_model(model, test_loader, device)
        
        if accuracy > best_accuracy:
            best_accuracy = accuracy
            print(f"New best accuracy: {best_accuracy:.2f}%")
            save_model(model, accuracy, config)
        else:
            print(f"Accuracy: {accuracy:.2f}% (best so far: {best_accuracy:.2f}%)")
    
    print(f"Training completed! Best accuracy: {best_accuracy:.2f}%")

# Main function to handle model training or loading
def main():
    config = load_environment_variables()
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")
    
    setup_directories(config)
    
    print("Attempting to load existing model...")
    model = load_existing_model(config, device)
    
    if model is not None:
        print("No training needed")
        sys.exit(0)
    
    print("No valid existing model found - proceeding with training")
    train_model(config, device)
    
    print("Verifying trained model...")
    model = load_existing_model(config, device)
    if model is not None:
        print("Trained model verified successfully")
        sys.exit(0)
    else:
        print("ERROR: Failed to verify trained model")
        sys.exit(1)


# Add current directory to path to make model imports work
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(current_dir)
from model import MNISTModel

# Environment variables setup
ENV_VARS = {
    'MODEL_BATCH_SIZE': None,
    'MODEL_EPOCHS': None,
    'MODEL_LEARNING_RATE': None,
    'MODEL_MOMENTUM': None,
    'CONTAINER_WORKDIR_NAME': None,
    'DATASET_DIR_NAME': None,
    'TRAINED_MODEL_DIR_NAME': None,
    'TRAINED_MODEL_NAME': None,
    'MODEL_FILE_NAME': None,
    'MNIST_DATASET_MEAN': None,
    'MNIST_DATASET_STD': None,
}

if __name__ == '__main__':
    main() 