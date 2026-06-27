# Build stage: bundle the front-end (React + Excalidraw + fonts) into /app/public.
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json ./
RUN npm install
COPY build.mjs ./
COPY src ./src
RUN node build.mjs

# Runtime stage: just the tiny server + the bundled static files. No network needed.
FROM node:20-alpine
WORKDIR /app
COPY server.js ./
COPY --from=build /app/public ./public
EXPOSE 7000
CMD ["node", "server.js"]
