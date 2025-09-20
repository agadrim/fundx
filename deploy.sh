#!/bin/bash

# AI Hedge Fund - Full Deployment Script
# This script builds and deploys the application locally in production mode

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[DEPLOY]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking deployment prerequisites..."
    
    local missing_deps=()
    
    # Check for Node.js
    if ! command_exists node; then
        missing_deps+=("Node.js (https://nodejs.org/)")
    fi
    
    # Check for npm
    if ! command_exists npm; then
        missing_deps+=("npm (comes with Node.js)")
    fi
    
    # Check for Python
    if ! command_exists python3; then
        missing_deps+=("Python 3 (https://python.org/)")
    fi
    
    # Check for Poetry
    if ! command_exists poetry; then
        missing_deps+=("Poetry (https://python-poetry.org/)")
    fi
    
    # Check for curl (optional but recommended for health checks)
    if ! command_exists curl; then
        print_warning "curl is not installed - health checks will be skipped"
        print_warning "Install curl for better deployment validation"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        print_error "Please install the missing dependencies and run this script again."
        exit 1
    fi
    
    print_success "All prerequisites are installed!"
}

# Function to setup environment variables
setup_environment() {
    print_status "Setting up environment variables..."
    
    # Check if .env exists
    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            print_warning "No .env file found. Creating from .env.example..."
            cp ".env.example" ".env"
            print_warning "Please edit the .env file to add your API keys:"
            print_warning "  - OPENAI_API_KEY=your-openai-api-key"
            print_warning "  - GROQ_API_KEY=your-groq-api-key"
            print_warning "  - FINANCIAL_DATASETS_API_KEY=your-financial-datasets-api-key"
            echo ""
            print_status "Press Enter to continue after editing .env file..."
            read -r
        else
            print_error "No .env or .env.example file found."
            print_error "Please create a .env file with your API keys."
            exit 1
        fi
    else
        print_success "Environment file (.env) found!"
    fi
    
    # Set production environment variables
    export NODE_ENV=production
    export PYTHONPATH="${PWD}:${PYTHONPATH}"
    
    print_success "Environment configured for production deployment"
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing all dependencies..."
    
    # Install root Python dependencies (exclude dev dependencies)
    print_status "Installing Python dependencies..."
    poetry install --without dev
    
    # Install frontend dependencies (include dev deps since we need Vite for build/preview)
    print_status "Installing frontend dependencies..."
    cd app/frontend
    npm ci
    cd ../..
    
    print_success "All dependencies installed!"
}

# Function to create production configuration
create_production_config() {
    print_status "Creating production configuration..."
    
    # Create production Vite config BEFORE building
    if [[ ! -f "app/frontend/.env.production" ]]; then
        cat > app/frontend/.env.production << EOF
VITE_API_URL=http://localhost:8000
NODE_ENV=production
EOF
        print_success "Created production environment config"
    fi
}

# Function to build the application
build_application() {
    print_status "Building application for production..."
    
    # Build frontend with production config
    print_status "Building frontend..."
    cd app/frontend
    NODE_ENV=production npm run build
    cd ../..
    
    # Check if build was successful
    if [[ ! -d "app/frontend/dist" ]]; then
        print_error "Frontend build failed - dist directory not found"
        exit 1
    fi
    
    print_success "Frontend built successfully!"
    
    # Prepare backend for production
    print_status "Preparing backend for production..."
    
    # Run database migrations if needed
    print_status "Running database migrations..."
    cd app/backend
    
    # Check if alembic is configured and installed
    if [[ -f "alembic.ini" ]] && [[ -d "alembic" ]]; then
        if poetry run alembic --version >/dev/null 2>&1; then
            if poetry run alembic upgrade head; then
                print_success "Database migrations completed"
            else
                print_error "Database migration failed"
                cd ../..
                exit 1
            fi
        else
            print_warning "Alembic not installed - skipping migrations"
        fi
    else
        print_warning "Alembic not configured - skipping migrations"
    fi
    cd ../..
    
    print_success "Application built and ready for deployment!"
}

# Function to create production runner
create_production_runner() {
    print_status "Creating production runner script..."
    
    # Create production runner script
    cat > start_production.sh << 'EOF'
#!/bin/bash

# Production startup script
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[PRODUCTION]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Load environment variables safely
if [[ -f ".env" ]]; then
    set -a
    source .env
    set +a
fi

export PYTHONPATH="${PWD}:${PYTHONPATH}"

print_status "Starting AI Hedge Fund in production mode..."

# Create log directory
mkdir -p logs

# Function to cleanup on exit
cleanup() {
    print_status "Shutting down production services..."
    
    if [[ -n "$BACKEND_PID" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
        kill "$BACKEND_PID" 2>/dev/null || true
    fi
    
    if [[ -n "$FRONTEND_PID" ]] && kill -0 "$FRONTEND_PID" 2>/dev/null; then
        kill "$FRONTEND_PID" 2>/dev/null || true
    fi
    
    print_success "Production services stopped!"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Start backend in production mode
print_status "Starting backend server (production)..."
poetry run uvicorn app.backend.main:app --host 0.0.0.0 --port 8000 --workers 4 > logs/backend.log 2>&1 &
BACKEND_PID=$!

# Wait for backend to start
sleep 5

# Check if backend started successfully
if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    print_error "Backend failed to start. Check logs/backend.log"
    cat logs/backend.log
    exit 1
fi

print_success "Backend server started (PID: $BACKEND_PID)"

# Start frontend preview server
print_status "Starting frontend preview server..."
cd app/frontend
npm run preview -- --host 0.0.0.0 --port 5000 > ../../logs/frontend.log 2>&1 &
FRONTEND_PID=$!
cd ../..

# Wait for frontend to start
sleep 3

# Check if frontend started successfully
if ! kill -0 "$FRONTEND_PID" 2>/dev/null; then
    print_error "Frontend failed to start. Check logs/frontend.log"
    cat logs/frontend.log
    cleanup
    exit 1
fi

print_success "Frontend preview server started (PID: $FRONTEND_PID)"

# Health checks
print_status "Performing health checks..."
sleep 2

# Check backend health
if command -v curl >/dev/null 2>&1; then
    if curl -s http://localhost:8000/health >/dev/null 2>&1; then
        print_success "Backend health check passed"
    else
        print_warning "Backend health check failed (endpoint may not exist)"
    fi
    
    if curl -s http://localhost:5000 >/dev/null 2>&1; then
        print_success "Frontend health check passed"
    else
        print_warning "Frontend health check failed"
    fi
else
    print_warning "curl not available - skipping health checks"
fi

echo ""
print_success "🚀 AI Hedge Fund is running in production mode!"
print_success "🌐 Frontend: http://localhost:5000"
print_success "🔧 Backend API: http://localhost:8000"
print_success "📖 API Docs: http://localhost:8000/docs"
print_success "📊 Logs: logs/ directory"
echo ""
print_status "Press Ctrl+C to stop all services"
echo ""

# Wait for user interrupt
while true; do
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
        print_error "Backend process died unexpectedly"
        break
    fi
    
    if ! kill -0 "$FRONTEND_PID" 2>/dev/null; then
        print_error "Frontend process died unexpectedly"  
        break
    fi
    
    sleep 5
done

cleanup
EOF

    chmod +x start_production.sh
    print_success "Production runner script created"
}

# Function to run tests
run_tests() {
    print_status "Running tests..."
    
    # Test backend
    print_status "Testing backend..."
    cd app/backend
    poetry run python -c "import app.backend.main; print('Backend imports successfully')" || {
        print_error "Backend import test failed"
        exit 1
    }
    cd ../..
    
    # Test frontend build
    print_status "Testing frontend build..."
    if [[ ! -d "app/frontend/dist" ]] || [[ ! -f "app/frontend/dist/index.html" ]]; then
        print_error "Frontend build test failed - missing dist files"
        exit 1
    fi
    
    print_success "All tests passed!"
}

# Function to validate deployment
validate_deployment() {
    print_status "Validating deployment setup..."
    
    # Check required files
    local required_files=(
        ".env"
        "app/frontend/dist/index.html"
        "app/backend/main.py"
        "poetry.lock"
        "app/frontend/package.json"
        "app/frontend/.env.production"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "Required file missing: $file"
            exit 1
        fi
    done
    
    # Check that frontend build has correct API URL
    if grep -q "localhost:8000" "app/frontend/dist/assets"/*.js 2>/dev/null; then
        print_success "Frontend build contains correct API URL"
    else
        print_warning "Could not verify API URL in frontend build"
    fi
    
    # Check ports are available
    if command_exists lsof; then
        if lsof -i :5000 >/dev/null 2>&1; then
            print_warning "Port 5000 is already in use"
        fi
        if lsof -i :8000 >/dev/null 2>&1; then
            print_warning "Port 8000 is already in use"
        fi
    fi
    
    print_success "Deployment validation passed!"
}

# Function to show deployment info
show_deployment_info() {
    echo ""
    print_success "🎯 Deployment completed successfully!"
    echo ""
    print_status "NEXT STEPS:"
    print_status "1. Run: ./start_production.sh"
    print_status "2. Access the application at: http://localhost:5000"
    print_status "3. API documentation at: http://localhost:8000/docs"
    echo ""
    print_status "PRODUCTION FILES:"
    print_status "- Frontend build: app/frontend/dist/"
    print_status "- Backend: app/backend/"
    print_status "- Environment: .env"
    print_status "- Production runner: start_production.sh"
    print_status "- Logs: logs/ (created when starting)"
    echo ""
    print_warning "IMPORTANT:"
    print_warning "- Make sure your .env file contains real API keys"
    print_warning "- For production deployment, consider using a reverse proxy (nginx)"
    print_warning "- Monitor logs in the logs/ directory"
    echo ""
}

# Main deployment function
main() {
    echo ""
    print_status "🚀 AI Hedge Fund - Full Deployment Script"
    print_status "This will build and deploy the application locally in production mode"
    echo ""
    
    check_prerequisites
    setup_environment
    install_dependencies
    create_production_config
    build_application
    create_production_runner
    run_tests
    validate_deployment
    show_deployment_info
}

# Show help if requested
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "AI Hedge Fund - Full Deployment Script"
    echo ""
    echo "Usage: ./deploy.sh"
    echo ""
    echo "This script will:"
    echo "  1. Check for required dependencies"
    echo "  2. Set up production environment"
    echo "  3. Install production dependencies"
    echo "  4. Build frontend for production"
    echo "  5. Prepare backend for production"
    echo "  6. Create production configuration"
    echo "  7. Run validation tests"
    echo "  8. Create production startup script"
    echo ""
    echo "After deployment:"
    echo "  - Run: ./start_production.sh"
    echo "  - Access: http://localhost:5000"
    echo "  - API: http://localhost:8000"
    echo ""
    exit 0
fi

# Run main deployment
main