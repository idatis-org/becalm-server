// FASTIFY SERVER

// run with $ node server
// Require fastify (www.fastify.io)
const fastify = require("fastify")({
    logger: {
        level: "info",
        prettyPrint: true,
    },
});

// use CORS without particular options
fastify.register(require("fastify-cors"), {
    origin: true,
});

// use ENV to manage server variables
// environment variables
const schema = {
    type: "object",
    required: ["ADDRESS", "PORT", "NODE_ENV"],
    properties: {
        ADDRESS: {
            type: "string",
        },
        PORT: {
            type: "integer",
            default: 4000,
        },
        NODE_ENV: {
            type: "string",
            default: "production",
        },
    },
};

// environment options
const options = {
    schema: schema,
    confKey: "config",
    // data: { PORT: 9999 },
    dotenv: true,
};

// Register option manager and output the configuration, then start the server
fastify.register(require("fastify-env"), options);

// register the database (need to load configuration first)
fastify.register(require("fastify-postgres"), {
    // consider abandoning fastify-env: https://github.com/fastify/fastify-env/issues/48
    connectionString: "postgres://becalm@localhost/becalm",
});

// Register Postgres database manager
// fastify.register(require("fastify-postgres"), {
//     connectionString: "postgres://becalm@localhost/becalm",
// });

// Register routes
fastify.register(require("./modules/v100/devices/routes"), { prefix: "v100" });
fastify.register(require("./modules/v100/patients/routes"), { prefix: "v100" });
fastify.register(require("./modules/v100/measures/routes"), { prefix: "v100" });

const start = async() => {
    try {
        // call ready() to ensure all plugins are loaded properly before calling listen()
        await fastify.ready();
        await fastify.listen(fastify.config.PORT);
        fastify.log.info(
            `Server listening on ${fastify.config.ADDRESS} - Environment is ${fastify.config.NODE_ENV}`
        );
        console.log("Fastify config = " + JSON.stringify(fastify.config));
    } catch (err) {
        fastify.log.error(err);
        process.exit(1);
    }
};
start();