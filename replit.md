# AI Hedge Fund - Replit Setup

## Overview
This is an AI-powered hedge fund application with both frontend and backend components. The system employs multiple AI agents working together to make trading decisions for educational purposes only.

## Recent Changes
- **Date: September 20, 2025** - Completed GitHub import setup for Replit environment
- Configured frontend (React/Vite) to run on port 5000 with host 0.0.0.0
- Configured backend (FastAPI) to run on port 8000 with localhost
- Set up CORS to allow all origins for Replit environment
- Fixed frontend API connections using environment variables

## Project Architecture
- **Frontend**: React with TypeScript, Vite build tool, TailwindCSS, shadcn/ui components
- **Backend**: FastAPI with Python, Poetry for dependency management, SQLAlchemy for database
- **Database**: PostgreSQL with Alembic migrations
- **AI Agents**: Multiple investment strategy agents using LangChain and various LLM providers

## User Preferences
- Uses Poetry for Python dependency management
- Prefers TypeScript for frontend development
- Uses modern React patterns with hooks and context

## Environment Configuration
- Frontend runs on port 5000 (configured for Replit proxy)
- Backend runs on port 8000
- Environment variables configured in .env file
- API connections configured using VITE_API_URL for frontend

## File Structure
- `/app/frontend/` - React frontend application
- `/app/backend/` - FastAPI backend application
- `/src/` - Core AI hedge fund logic and agents
- Root contains Poetry configuration and main project files

## Dependencies
- Python 3.11+ with Poetry
- Node.js 20 with npm
- Various AI/ML libraries (LangChain, FastAPI, etc.)
- React ecosystem (Vite, TypeScript, TailwindCSS)

## Notes
- This is for educational purposes only, not real trading
- Multiple LLM providers supported (OpenAI, Anthropic, Groq, etc.)
- Includes backtesting functionality
- Web interface provides visual flow-based agent configuration