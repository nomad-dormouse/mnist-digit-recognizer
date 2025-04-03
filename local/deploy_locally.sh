#!/bin/bash
# Local deployment wrapper for MNIST Digit Recognizer

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Change to project root directory
cd "$PROJECT_ROOT"

# Set local environment variables
export IS_DEVELOPMENT=true
export PORT=8501
export DB_CONTAINER_NAME=mnist-digit-recognizer-db
export WEB_CONTAINER_NAME=mnist-digit-recognizer-web
export DB_NAME=mnist_db
export DB_USER=postgres
export DB_PASSWORD=postgres
export DB_HOST=db
export DB_PORT=5432

# Create local override file if it doesn't exist
OVERRIDE_FILE="docker-compose.override.yml"
if [ ! -f "$OVERRIDE_FILE" ]; then
    cat > "$OVERRIDE_FILE" << EOF
version: '3.8'

services:
  web:
    ports:
      - "${PORT}:8501"
    volumes:
      - ./:/app
    environment:
      - KMP_DUPLICATE_LIB_OK=TRUE
      - IS_DEVELOPMENT=true
      - DB_HOST=db
      - DB_PORT=5432
      - DB_NAME=mnist_db
      - DB_USER=postgres
      - DB_PASSWORD=postgres
    depends_on:
      - db

  db:
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=mnist_db

volumes:
  postgres_data:
EOF
    echo "Created local override file: $OVERRIDE_FILE"
fi

# Run the main deployment script with local settings
"$SCRIPT_DIR/deploy_base.sh" -e development -f docker-compose.yml "$@"

# If 'up' action and no errors, open browser
if [[ $? -eq 0 && ("$1" == "up" || $# -eq 0) ]]; then
    # Wait a moment for the application to fully start
    sleep 5
    
    # Open browser (works on macOS, Linux with xdg-open, or Windows with start)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "http://localhost:${PORT}"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open "http://localhost:${PORT}" &>/dev/null
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        start "http://localhost:${PORT}"
    else
        echo "Browser not opened automatically. Visit: http://localhost:${PORT}"
    fi
fi