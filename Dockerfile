# Use Node.js 16 as base image
FROM node:16-alpine

# Set working directory inside container
WORKDIR /usr/src/app

# Copy package files first for better layer caching
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production || npm install --production

# Copy application source code
COPY . .

# Set environment variable (Express app typically uses PORT)
ENV PORT=8080
EXPOSE 8080

# Start the app
CMD ["node", "app.js"]
