# =============================================================================
# Script: create_noe_crm_project.ps1
# Description: Ce script automatise la création de la structure complète
#              du projet Noé CRM, y compris tous les dossiers et fichiers
#              source nécessaires à son déploiement.
#
# Usage:
# 1. Enregistrez ce fichier sous le nom 'create_noe_crm_project.ps1'.
# 2. Ouvrez un terminal PowerShell.
# 3. Naviguez jusqu'au répertoire où vous avez enregistré le script.
# 4. Exécutez le script avec la commande : .\create_noe_crm_project.ps1
#
# Auteur: Neo
# Version: 1.0
# Date: 09/05/2025
# =============================================================================

# --- Configuration ---
$ProjectName = "noe-crm-project"
$BaseDir = Join-Path -Path $PSScriptRoot -ChildPath $ProjectName

# --- Début du Script ---
Write-Host "--- Démarrage du script de création du projet Noé CRM ---" -ForegroundColor Cyan
Write-Host "Le projet sera créé dans le dossier : $BaseDir"
Write-Host ""

# --- Fonction pour créer des fichiers avec leur contenu ---
function New-FileWithContent {
    param(
        [string]$Path,
        [string]$Content
    )
    try {
        # S'assurer que le répertoire parent existe
        $ParentDir = Split-Path -Path $Path -Parent
        if (-not (Test-Path -Path $ParentDir)) {
            New-Item -ItemType Directory -Path $ParentDir -Force | Out-Null
        }
        
        # Créer le fichier avec le contenu encodé en UTF-8
        Set-Content -Path $Path -Value $Content -Encoding UTF8 -Force
        Write-Host "    -> Fichier créé : $Path" -ForegroundColor Green
    } catch {
        Write-Host "    -> ERREUR lors de la création du fichier $Path : $_" -ForegroundColor Red
        exit 1
    }
}

# --- Étape 1: Création de l'arborescence des dossiers ---
Write-Host "[ÉTAPE 1/2] Création de la structure des dossiers..." -ForegroundColor Yellow

if (Test-Path $BaseDir) {
    Write-Host "Le dossier '$ProjectName' existe déjà. Suppression..." -ForegroundColor Magenta
    Remove-Item -Recurse -Force -Path $BaseDir
}
New-Item -ItemType Directory -Path $BaseDir | Out-Null

# Dossiers principaux
$BackendDir = Join-Path -Path $BaseDir -ChildPath "backend"
$FrontendDir = Join-Path -Path $BaseDir -ChildPath "frontend"
$ProxyDir = Join-Path -Path $BaseDir -ChildPath "proxy"
New-Item -ItemType Directory -Path $BackendDir, $FrontendDir, $ProxyDir | Out-Null

# Sous-dossiers Backend
$AppDir = Join-Path -Path $BackendDir -ChildPath "app"
New-Item -ItemType Directory -Path $AppDir | Out-Null
$ApiDir = Join-Path -Path $AppDir -ChildPath "api"
$CoreDir = Join-Path -Path $AppDir -ChildPath "core"
$ModelsDir = Join-Path -Path $AppDir -ChildPath "models"
New-Item -ItemType Directory -Path $ApiDir, $CoreDir, $ModelsDir | Out-Null

# Sous-dossiers Frontend
$SrcDir = Join-Path -Path $FrontendDir -ChildPath "src"
New-Item -ItemType Directory -Path $SrcDir | Out-Null
$ComponentsDir = Join-Path -Path $SrcDir -ChildPath "components"
$PagesDir = Join-Path -Path $SrcDir -ChildPath "pages"
New-Item -ItemType Directory -Path $ComponentsDir, $PagesDir | Out-Null

Write-Host "Structure des dossiers créée avec succès."
Write-Host ""

# --- Étape 2: Création des fichiers avec leur contenu ---
Write-Host "[ÉTAPE 2/2] Création des fichiers du projet..." -ForegroundColor Yellow

# --- Fichier docker-compose.yml --- 
$dockerComposeContent = @'
docker-compose.yml
version: '3.8'

services:
  backend:
    build: ./backend
    container_name: noe_crm_backend
    restart: unless-stopped
    volumes:
      - ./backend:/app
    environment:
      - FLASK_ENV=development
      - SECRET_KEY=a-super-secret-key-that-should-be-changed

  frontend:
    build: ./frontend
    container_name: noe_crm_frontend
    ports:
      - "5173:5173"
    volumes:
      - ./frontend:/app
      - /app/node_modules # Evite l'écrasement du node_modules du conteneur
    depends_on:
      - backend

  proxy:
    build: ./proxy
    container_name: noe_crm_proxy
    restart: unless-stopped
    ports:
      - "8080:80"
    depends_on:
      - frontend
      - backend

volumes:
  backend_data:
  frontend_data:
'@
New-FileWithContent -Path (Join-Path -Path $BaseDir -ChildPath "docker-compose.yml") -Content $dockerComposeContent

# --- Fichiers du Backend --- 

# backend/Dockerfile
$backendDockerfileContent = @'
# Utiliser une image Python officielle.
FROM python:3.9-slim

# Définir le répertoire de travail dans le conteneur
WORKDIR /app

# Copier les dépendances et les installer
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copier le reste du code de l'application
COPY . .

# Exposer le port que Flask utilisera
EXPOSE 5000

# Commande pour lancer l'application
CMD ["flask", "run", "--host=0.0.0.0"]
'@
New-FileWithContent -Path (Join-Path -Path $BackendDir -ChildPath "Dockerfile") -Content $backendDockerfileContent

# backend/requirements.txt
$backendRequirementsContent = @'
Flask
Flask-SQLAlchemy
Flask-Migrate
Flask-JWT-Extended
Flask-Cors
python-dotenv
'@
New-FileWithContent -Path (Join-Path -Path $BackendDir -ChildPath "requirements.txt") -Content $backendRequirementsContent

# backend/run.py
$backendRunPyContent = @'
from app import create_app

app = create_app()

if __name__ == '__main__':
    app.run(debug=True)
'@
New-FileWithContent -Path (Join-Path -Path $BackendDir -ChildPath "run.py") -Content $backendRunPyContent

# backend/app/__init__.py
$backendAppInitContent = @'
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager
from flask_cors import CORS
from .core.config import Config

db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()

def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    CORS(app, resources={r"/api/*": {"origins": "*"}})

    from app.api.auth import auth_bp
    from app.api.main import main_bp
    
    app.register_blueprint(auth_bp, url_prefix='/api/v1/auth')
    app.register_blueprint(main_bp, url_prefix='/api/v1')

    with app.app_context():
        db.create_all() # Crée les tables si elles n'existent pas

    return app
'@
New-FileWithContent -Path (Join-Path -Path $AppDir -ChildPath "__init__.py") -Content $backendAppInitContent

# backend/app/core/config.py
$backendCoreConfigContent = @'
import os
from datetime import timedelta

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'default-secret-key-for-dev'
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'sqlite:///site.db'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY') or 'default-jwt-secret-key'
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=1)
'@
New-FileWithContent -Path (Join-Path -Path $CoreDir -ChildPath "config.py") -Content $backendCoreConfigContent

# backend/app/models/user.py
$backendModelsUserContent = @'
from app import db
from werkzeug.security import generate_password_hash, check_password_hash

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(128))

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
'@
New-FileWithContent -Path (Join-Path -Path $ModelsDir -ChildPath "user.py") -Content $backendModelsUserContent

# backend/app/api/auth.py
$backendApiAuthContent = @'
from flask import Blueprint, request, jsonify
from app.models.user import User
from app import db
from flask_jwt_extended import create_access_token

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    if User.query.filter_by(username=data['username']).first() or User.query.filter_by(email=data['email']).first():
        return jsonify({'message': 'User already exists'}), 409

    new_user = User(username=data['username'], email=data['email'])
    new_user.set_password(data['password'])
    db.session.add(new_user)
    db.session.commit()
    return jsonify({'message': 'User created successfully'}), 201

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    user = User.query.filter_by(email=data['email']).first()

    if user and user.check_password(data['password']):
        access_token = create_access_token(identity={'username': user.username, 'email': user.email})
        return jsonify(access_token=access_token), 200
    
    return jsonify({'message': 'Invalid credentials'}), 401
'@
New-FileWithContent -Path (Join-Path -Path $ApiDir -ChildPath "auth.py") -Content $backendApiAuthContent

# backend/app/api/main.py
$backendApiMainContent = @'
from flask import Blueprint, jsonify

main_bp = Blueprint('main', __name__)

@main_bp.route('/status', methods=['GET'])
def status():
    return jsonify({'status': 'Backend is running!'}), 200
'@
New-FileWithContent -Path (Join-Path -Path $ApiDir -ChildPath "main.py") -Content $backendApiMainContent


# --- Fichiers du Frontend --- 

# frontend/Dockerfile
$frontendDockerfileContent = @'
# Stage 1: Build
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2: Production environment
FROM node:18-alpine
WORKDIR /app
COPY --from=build /app/dist /app/dist
COPY --from=build /app/package.json /app/package.json

# This is just to have something to run, Nginx will serve the files
CMD ["npm", "run", "preview", "--", "--host"]
'@
New-FileWithContent -Path (Join-Path -Path $FrontendDir -ChildPath "Dockerfile") -Content $frontendDockerfileContent

# frontend/package.json
$frontendPackageJsonContent = @'
{
  "name": "noe-crm-frontend",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "lint": "eslint . --ext ts,tsx --report-unused-disable-directives --max-warnings 0",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.22.3"
  },
  "devDependencies": {
    "@types/react": "^18.2.66",
    "@types/react-dom": "^18.2.22",
    "@typescript-eslint/eslint-plugin": "^7.2.0",
    "@typescript-eslint/parser": "^7.2.0",
    "@vitejs/plugin-react": "^4.2.1",
    "autoprefixer": "^10.4.19",
    "eslint": "^8.57.0",
    "eslint-plugin-react-hooks": "^4.6.0",
    "eslint-plugin-react-refresh": "^0.4.6",
    "postcss": "^8.4.38",
    "tailwindcss": "^3.4.3",
    "typescript": "^5.2.2",
    "vite": "^5.2.0"
  }
}
'@
New-FileWithContent -Path (Join-Path -Path $FrontendDir -ChildPath "package.json") -Content $frontendPackageJsonContent

# frontend/vite.config.ts
$frontendViteConfigContent = @'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: true, // Needed for Docker
    port: 5173,
    strictPort: true,
    watch: {
      usePolling: true
    }
  }
})
'@
New-FileWithContent -Path (Join-Path -Path $FrontendDir -ChildPath "vite.config.ts") -Content $frontendViteConfigContent

# frontend/tsconfig.json
$frontendTsConfigContent = @'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
'@
New-FileWithContent -Path (Join-Path -Path $FrontendDir -ChildPath "tsconfig.json") -Content $frontendTsConfigContent

# frontend/tsconfig.node.json
$frontendTsConfigNodeContent = @'
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true
  },
  "include": ["vite.config.ts"]
}
'@
New-FileWithContent -Path (Join-Path -Path $FrontendDir -ChildPath "tsconfig.node.json") -Content $frontendTsConfigNodeContent

# frontend/tailwind.config.js
$frontendTailwindConfigContent = @'
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
'@
New-FileWithContent -Path (Join-Path -Path $FrontendDir -ChildPath "tailwind.config.js") -Content $frontendTailwindConfigContent

# frontend/postcss.config.js
$frontendPostcssConfigContent = @'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
'@
New-FileWithContent -Path (Join-Path -Path $FrontendDir -ChildPath "postcss.config.js") -Content $frontendPostcssConfigContent

# frontend/index.html
$frontendIndexHtmlContent = @'
<!doctype html>
<html lang="fr">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Noé CRM</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
'@
New-FileWithContent -Path (Join-Path -Path $FrontendDir -ChildPath "index.html") -Content $frontendIndexHtmlContent

# frontend/src/index.css
$frontendIndexCssContent = @'
@tailwind base;
@tailwind components;
@tailwind utilities;
'@
New-FileWithContent -Path (Join-Path -Path $SrcDir -ChildPath "index.css") -Content $frontendIndexCssContent

# frontend/src/main.tsx
$frontendMainTsxContent = @'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'
import { BrowserRouter } from 'react-router-dom'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </React.StrictMode>,
)
'@
New-FileWithContent -Path (Join-Path -Path $SrcDir -ChildPath "main.tsx") -Content $frontendMainTsxContent

# frontend/src/App.tsx
$frontendAppTsxContent = @'
import { Routes, Route, Link } from 'react-router-dom';
import LoginPage from './pages/LoginPage';

function App() {
  return (
    <div className="min-h-screen bg-gray-100">
      <nav className="bg-white shadow p-4">
        <Link to="/" className="text-xl font-bold">Noé CRM</Link>
      </nav>
      <main className="p-8">
        <Routes>
          <Route path="/" element={<LoginPage />} />
          {/* Ajoutez d'autres routes ici */}
        </Routes>
      </main>
    </div>
  )
}

export default App;
'@
New-FileWithContent -Path (Join-Path -Path $SrcDir -ChildPath "App.tsx") -Content $frontendAppTsxContent

# frontend/src/pages/LoginPage.tsx
$frontendLoginPageTsxContent = @'
import React, { useState } from 'react';

export default function LoginPage() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        // Logique de connexion à venir
        console.log({ email, password });
        alert("Connexion en cours...");
    };

    return (
        <div className="max-w-md mx-auto bg-white p-8 rounded-lg shadow-md">
            <h2 className="text-2xl font-bold mb-6 text-center">Connexion</h2>
            <form onSubmit={handleSubmit}>
                <div className="mb-4">
                    <label className="block text-gray-700">Email</label>
                    <input 
                        type="email" 
                        className="w-full p-2 border border-gray-300 rounded mt-1"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        required
                    />
                </div>
                <div className="mb-6">
                    <label className="block text-gray-700">Mot de passe</label>
                    <input 
                        type="password" 
                        className="w-full p-2 border border-gray-300 rounded mt-1"
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        required
                    />
                </div>
                <button type="submit" className="w-full bg-blue-500 text-white p-2 rounded hover:bg-blue-600">
                    Se connecter
                </button>
            </form>
        </div>
    );
}
'@
New-FileWithContent -Path (Join-Path -Path $PagesDir -ChildPath "LoginPage.tsx") -Content $frontendLoginPageTsxContent


# --- Fichiers du Proxy --- 

# proxy/Dockerfile
$proxyDockerfileContent = @'
FROM nginx:alpine

# Supprimer la configuration par défaut
RUN rm /etc/nginx/conf.d/default.conf

# Copier notre configuration personnalisée
COPY nginx.conf /etc/nginx/conf.d
'@
New-FileWithContent -Path (Join-Path -Path $ProxyDir -ChildPath "Dockerfile") -Content $proxyDockerfileContent

# proxy/nginx.conf
$proxyNginxConfContent = @'
server {
    listen 80;

    # Route pour l'API backend
    location /api/ {
        proxy_pass http://backend:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Route pour l'application frontend React
    location / {
        proxy_pass http://frontend:5173;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade; # Pour le Hot Module Replacement de Vite
        proxy_set_header Connection "Upgrade";
    }
}
'@
New-FileWithContent -Path (Join-Path -Path $ProxyDir -ChildPath "nginx.conf") -Content $proxyNginxConfContent


Write-Host ""
Write-Host "--- SUCCÈS ---" -ForegroundColor Green
Write-Host "Le projet Noé CRM a été créé avec succès dans le dossier '$ProjectName'."
Write-Host "Prochaines étapes :"
Write-Host "  1. Accédez au dossier du projet : cd $ProjectName"
Write-Host "  2. Lancez le projet avec Docker : docker-compose up --build -d"

