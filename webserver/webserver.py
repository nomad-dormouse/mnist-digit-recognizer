# Standard library imports
import os
import sys
import datetime
from pathlib import Path

# Third-party imports
import torch
from torchvision import transforms
import numpy as np
from PIL import Image
import psycopg2
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn


# Create FastAPI app
fastApiApp = FastAPI(title="MNIST Digit Recogniser Web Server")


# Pydantic models for request/response
class PredictionRequest(BaseModel):
    image_data: list[list[list[int]]]
    model_config = {
        "arbitrary_types_allowed": True,
    }

class PredictionResponse(BaseModel):
    predicted_digit: int
    confidence: float

class PredictionLogRequest(BaseModel):
    predicted_digit: int
    confidence: float
    true_label: int

class PredictionHistoryResponse(BaseModel):
    timestamp: datetime.datetime
    predicted_digit: int
    true_label: int | None
    confidence: float


# Load environment variables, return processed configuration
def load_environment_variables():
    for var in ENV_VARS:
        ENV_VARS[var] = os.getenv(var)
        if ENV_VARS[var] is None:
            raise HTTPException(status_code=500, detail=f"Missing required environment variable: {var}")
    config = {
        'dataset': {
            'image_size': int(ENV_VARS['MNIST_DATASET_IMAGE_SIZE']),
            'mean': float(ENV_VARS['MNIST_DATASET_MEAN']),
            'std': float(ENV_VARS['MNIST_DATASET_STD']),
        },
        'model': {
            'path': Path(f"/{ENV_VARS['CONTAINER_WORKDIR_NAME']}/{ENV_VARS['TRAINED_MODEL_DIR_NAME']}/{ENV_VARS['TRAINED_MODEL_NAME']}"),
            'file': ENV_VARS['MODEL_FILE_NAME']
        },
        'db': {
            'host': ENV_VARS['DB_SERVICE_NAME'],
            'port': ENV_VARS['DB_PORT'],
            'database': ENV_VARS['DB_NAME'],
            'user': ENV_VARS['DB_USER'],
            'password': ENV_VARS['DB_PASSWORD'],
            'timeout': int(ENV_VARS['DB_TIMEOUT'])
        }
    }
    return config


# Get a connection to the PostgreSQL database
def get_db_connection():
    try:
        return psycopg2.connect(
            host=CONFIG['db']['host'],
            port=CONFIG['db']['port'],
            database=CONFIG['db']['database'],
            user=CONFIG['db']['user'],
            password=CONFIG['db']['password'],
            connect_timeout=CONFIG['db']['timeout']
        )
    except psycopg2.Error as e:
        raise HTTPException(status_code=500, detail=f"Database connection error: {str(e)}")

# Load the trained model if not already loaded
def load_model():
    global MODEL
    if MODEL is None:
        try:
            if not CONFIG['model']['path'].exists():
                raise FileNotFoundError(f"Model not found at: {CONFIG['model']['path']}")
            
            model_dir = CONFIG['model']['path'].parent
            if str(model_dir) not in sys.path:
                sys.path.append(str(model_dir))
            
            from model import MNISTModel
            
            device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
            MODEL = MNISTModel().to(device)
            
            MODEL.load_state_dict(torch.load(CONFIG['model']['path'], map_location=device))
            MODEL.eval()

        except Exception as e:
            import traceback
            print(f"Error loading model: {str(e)}")
            print(traceback.format_exc())
            raise HTTPException(status_code=500, detail=f"Model loading error: {str(e)}")
    return MODEL

# Process the image data for prediction
def process_image(image_data):
    try:
        # Convert image_data to PIL Image
        image_pil = Image.fromarray(np.array(image_data, dtype=np.uint8))
        # Convert RGBA to Grayscale
        image_gray = image_pil.convert('L')
        # Resize to MNIST size
        image_size = CONFIG['dataset']['image_size']
        image_resized = image_gray.resize((image_size, image_size))
        print(f"Image resized: {np.array(image_resized)}")
        # Convert to float tensor: shape (1, image_size, image_size), range [0, 1]
        image_tensor = transforms.ToTensor()(image_resized)
        # Apply MNIST normalization
        image_mean = CONFIG['dataset']['mean']
        image_std = CONFIG['dataset']['std']
        image_tensor = transforms.Normalize((image_mean,), (image_std,))(image_tensor)
        # Add batch dimension
        image_tensor = image_tensor.unsqueeze(0)
        return image_tensor
    except Exception as e:
        import traceback
        print(f"Error processing image: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=400, detail=f"Image processing error: {str(e)}")

# Make a prediction with the model
def predict(image_tensor):
    model = load_model()
    device = next(model.parameters()).device
    image_tensor = image_tensor.to(device)
    
    with torch.no_grad():
        output = model(image_tensor)
        probabilities = torch.nn.functional.softmax(output, dim=1)
        prediction = output.argmax(dim=1)
        confidence = probabilities.max(dim=1)[0]
    
    return prediction.item(), confidence.item()


# Health check endpoint
@fastApiApp.get("/health")
async def health_check():
    try:
        conn = get_db_connection()
        conn.close()
        return {"status": "healthy"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Health check failed: {str(e)}")

# Endpoint to get prediction history
@fastApiApp.get("/prediction-history")
async def get_prediction_history(limit: int = 10):
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT timestamp, predicted_digit, true_label, confidence FROM predictions ORDER BY timestamp DESC LIMIT %s",
                (limit,)
            )
            predictions = cur.fetchall()
            return [
                PredictionHistoryResponse(
                    timestamp=timestamp,
                    predicted_digit=predicted_digit,
                    true_label=true_label,
                    confidence=confidence
                )
                for timestamp, predicted_digit, true_label, confidence in predictions
            ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching prediction history: {str(e)}")
    finally:
        conn.close()

# Endpoint for digit prediction
@fastApiApp.post("/predict", response_model=PredictionResponse)
async def predict_digit(request: PredictionRequest):
    try:
        image_tensor = process_image(request.image_data)
        prediction, confidence = predict(image_tensor)
        return PredictionResponse(predicted_digit=prediction, confidence=confidence)
    except Exception as e:
        import traceback
        print(f"Error in predict_digit: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")

# Endpoint to log a prediction to the database
@fastApiApp.post("/log-prediction")
async def log_prediction(request: PredictionLogRequest):
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO predictions (predicted_digit, true_label, confidence, timestamp) VALUES (%s, %s, %s, %s)",
                (request.predicted_digit, request.true_label, request.confidence, datetime.datetime.now())
            )
            conn.commit()
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error logging prediction: {str(e)}")
    finally:
        conn.close()


ENV_VARS = {
    'DB_SERVICE_NAME': None,
    'DB_PORT': None,
    'DB_NAME': None,
    'DB_USER': None,
    'DB_PASSWORD': None,
    'DB_TIMEOUT': None,
    'CONTAINER_WORKDIR_NAME': None,
    'TRAINED_MODEL_DIR_NAME': None,
    'TRAINED_MODEL_NAME': None,
    'MODEL_FILE_NAME': None,
    'MNIST_DATASET_IMAGE_SIZE': None,
    'MNIST_DATASET_MEAN': None,
    'MNIST_DATASET_STD': None,
    'WEBSERVER_PORT': None,
}
CONFIG = load_environment_variables()

MODEL = None
MODEL = load_model()

if __name__ == "__main__":
    port = int(ENV_VARS['WEBSERVER_PORT'])
    uvicorn.run(fastApiApp, host="0.0.0.0", port=port) 