const http = require("node:http");
const { config } = require("./config");
const { createApp } = require("./app");
const { createServices } = require("./services");

/// Starts the plaintext development API server.
function startServer(options = {}) {
  const services = options.services || createServices();
  const app = createApp(services);
  const server = http.createServer(app);
  const port = options.port || config.port;
  const host = options.host || config.host;

  server.listen(port, host, () => {
    const address = server.address();
    console.log(`PrivateImageVault API listening at http://${address.address}:${address.port}`);
  });

  return server;
}

/// Running this file directly starts the server.
if (require.main === module) {
  startServer();
}

module.exports = {
  startServer
};
