FROM node:20-bullseye

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libvips-dev python3 make g++ git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/app

# Install Strapi (Quickstart) & Clean Cache
RUN npx create-strapi-app@4.25.4 my-project \
    --quickstart --no-run --skip-cloud \
    && rm -rf /root/.npm /root/.cache /tmp/*

WORKDIR /opt/app/my-project

# INSTALL POSTGRES DRIVER
RUN npm install pg --save

# COPY CUSTOM DATABASE CONFIG
COPY config/database.js ./config/database.js

# Rebuild and optimize
RUN npm rebuild sharp && npm run build && rm -rf /root/.npm

ENV HOST=0.0.0.0
ENV PORT=1337

EXPOSE 1337
CMD ["npm", "run", "develop"]