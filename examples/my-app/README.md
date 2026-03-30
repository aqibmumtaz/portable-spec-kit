# My App

A task management application with real-time collaboration.

## Overview
My App helps teams track tasks, assign work, and collaborate in real-time. Built with Next.js and Supabase.

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Frontend | Next.js 14 + TypeScript + Tailwind CSS |
| Backend | Next.js API Routes |
| Database | Supabase (PostgreSQL) |
| Auth | Supabase Auth |
| Hosting | Vercel |

## Getting Started

### Prerequisites
- Node.js 18+
- npm or yarn

### Installation
```bash
git clone https://github.com/you/my-app.git
cd my-app
npm install
```

### Running Locally
```bash
npm run dev    # http://localhost:3456
```

### Environment Variables
Copy `.env.example` to `.env` and fill in your keys.

## Project Structure
```
src/
├── app/           ← Pages and routes
├── components/    ← UI components
├── lib/           ← Utilities and configs
└── types/         ← TypeScript types
```

## Features
- Task creation and assignment
- Real-time updates via Supabase subscriptions
- Team workspaces
- Due date tracking

## Testing
```bash
npm test              # run tests
npm run test:coverage # with coverage
```

## Deployment
Deployed on Vercel. Push to `main` triggers auto-deploy.

## Author
Your Name

## License
MIT
