FROM nodered/node-red:4.0.9@sha256:7a3e18f29578feb271bb8daab4379e4ebd355b87ea64b699ce74e6ff49d907aa

WORKDIR /usr/src/node-red

RUN npm install @node-red-contrib-themes/theme-collection
RUN npm install node-red-contrib-uuid
RUN npm install node-red-contrib-cron-plus
RUN npm install node-red-contrib-redis
RUN npm install node-red-contrib-chronos
RUN npm install node-red-node-random
RUN npm install node-red-contrib-loop-processing
