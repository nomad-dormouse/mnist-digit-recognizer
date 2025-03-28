# MNIST Digit Recognizer

A full-stack machine learning application that allows users to draw digits and get real-time predictions using a PyTorch model trained on the MNIST dataset.

**Live Demo**: [http://37.27.197.79:8501](http://37.27.197.79:8501)

**GitHub Repository**: [https://github.com/nomad-dormouse/mnist-digit-recognizer](https://github.com/nomad-dormouse/mnist-digit-recognizer)

## Features

- Deep learning model for handwritten digit classification (PyTorch)
- Interactive web interface with drawing canvas (Streamlit)
- Database for prediction logging and analytics (PostgreSQL)
- Containerized deployment with Docker and Docker Compose
- Automated deployment pipeline

## Project Overview

This project demonstrates an end-to-end machine learning application that:

1. Implements a PyTorch Convolutional Neural Network (CNN) trained on the MNIST dataset
2. Provides an intuitive web interface for drawing digits and receiving real-time predictions
3. Records predictions and user feedback in a PostgreSQL database for continuous improvement
4. Deploys seamlessly using containerization for consistent environments

## Project Structure

```
.
├── app/                    # Streamlit web application
├── model/                  # PyTorch model and training code
├── database/               # Database schemas and tools
│   └── init.sql           # Database initialization script
├── docker/                 # Docker configuration files
│   └── docker-compose.yml # Multi-container Docker setup
├── local/                  # Local development tools and setup
├── saved_models/          # Saved model weights
├── server/                 # Server management tools
│   ├── check_web_logs.sh  # Web container logs viewer
│   ├── deploy.sh          # Deployment script
│   ├── view_db.sh         # Database statistics viewer
│   └── .env               # Environment variables
├── requirements.txt        # Python dependencies
```

## Local Development

For detailed instructions on setting up and running the application locally, please refer to the [Local Development Guide](local/README.md).

This includes:
- Quick setup with Docker
- Manual setup instructions
- Database initialization
- Environment configuration
- Development tools

## Deployment

To deploy the application to a production server:

1. **Update deployment configuration:**
   Edit `server/deploy.sh` and update:
   - `REMOTE_HOST` with your server IP
   - `SSH_KEY` with your SSH key path
   - `REPO_URL` with your GitHub repository URL

2. **Run the deployment script:**
   ```bash
   ./server/deploy.sh
   ```

3. **Access the deployed application:**
   Open your browser and navigate to `http://your-server-ip:8501`

## Technical Details

### Model Architecture

The digit recognition model is a Convolutional Neural Network (CNN) with:
- 2 convolutional layers with ReLU activation
- Max pooling layers for spatial dimensionality reduction
- Dropout regularization to prevent overfitting
- 2 fully connected layers for classification
- Trained to >99% accuracy on the MNIST dataset

### Database Schema

The PostgreSQL database stores predictions with:
- `id`: Auto-incrementing primary key
- `timestamp`: When the prediction was made
- `predicted_digit`: Model's prediction (0-9)
- `true_label`: User-provided correct label (for feedback)
- `confidence`: Model's confidence score (probability)

## AI Development Acknowledgment

This project was developed with assistance from AI tools:
- [Cursor](https://cursor.sh/) - An AI-powered code editor that provided intelligent code suggestions
- The development process involved AI-assisted coding, debugging, and documentation generation, with human oversight for all critical decisions

## License

[MIT License](LICENSE) 
