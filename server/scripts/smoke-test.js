const http = require("node:http");
const path = require("node:path");
const { createApp } = require("../src/app");
const { createServices } = require("../src/services");

/// Starts an isolated server instance for the smoke test.
async function startIsolatedServer() {
  const runtimeRoot = path.resolve(__dirname, "..", ".runtime", `smoke-${Date.now()}`);
  const services = createServices({
    dbFilePath: path.join(runtimeRoot, "db.json"),
    objectStorageRoot: path.join(runtimeRoot, "objects")
  });

  const server = http.createServer(createApp(services));

  await new Promise((resolve) => {
    server.listen(0, "127.0.0.1", resolve);
  });

  const address = server.address();

  return {
    server,
    baseURL: `http://${address.address}:${address.port}`
  };
}

/// Sends a JSON request and returns the decoded JSON response.
async function jsonRequest(baseURL, method, pathName, body, token) {
  const response = await fetch(`${baseURL}${pathName}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });

  const payload = await response.json();

  if (!response.ok) {
    throw new Error(`${method} ${pathName} failed: ${JSON.stringify(payload)}`);
  }

  return payload;
}

/// Runs the end-to-end plaintext delivery flow.
async function main() {
  const { server, baseURL } = await startIsolatedServer();

  try {
    const alice = await jsonRequest(baseURL, "POST", "/v1/auth/register", {
      username: "alice",
      password: "correct horse battery staple"
    });

    const bob = await jsonRequest(baseURL, "POST", "/v1/auth/register", {
      username: "bob",
      password: "correct horse battery staple"
    });

    const imageBytes = Buffer.from("fake-jpeg-bytes-for-plaintext-smoke-test");

    const uploadResponse = await fetch(`${baseURL}/v1/objects`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${alice.token}`,
        "Content-Type": "image/jpeg"
      },
      body: imageBytes
    });

    const uploaded = await uploadResponse.json();

    if (!uploadResponse.ok) {
      throw new Error(`object upload failed: ${JSON.stringify(uploaded)}`);
    }

    const messageResponse = await jsonRequest(
      baseURL,
      "POST",
      "/v1/image-messages",
      {
        recipientUserId: bob.user.id,
        objectId: uploaded.object.id
      },
      alice.token
    );

    const inbox = await jsonRequest(baseURL, "GET", "/v1/image-messages/inbox", null, bob.token);

    if (inbox.messages.length !== 1) {
      throw new Error(`expected 1 inbox message, got ${inbox.messages.length}`);
    }

    const downloadResponse = await fetch(`${baseURL}/v1/objects/${uploaded.object.id}`, {
      headers: {
        Authorization: `Bearer ${bob.token}`
      }
    });

    const downloaded = Buffer.from(await downloadResponse.arrayBuffer());

    if (!downloadResponse.ok || !downloaded.equals(imageBytes)) {
      throw new Error("downloaded object bytes did not match uploaded bytes");
    }

    await jsonRequest(
      baseURL,
      "POST",
      `/v1/image-messages/${messageResponse.message.id}/seen`,
      null,
      bob.token
    );

    console.log("Smoke test passed: register, upload, send, inbox, download, seen.");
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
