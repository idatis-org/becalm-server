const { listMeasuresSchema, postMeasuresSchema } = require("./schema");

// GET measures
module.exports = (fastify, options, done) => {
    // GET sensor data from a patient
    fastify.route({
        method: "GET",
        url: "/data-sensor/:id_patient",
        schema: listMeasuresSchema,
        handler: async(request, reply) => {
            // build filter object passed to the database to retrieve data
            const filter = {
                id_patient: request.params.id_patient,
                start_date: request.query.start_date,
            };

            if (request.query.end_date) {
                filter.end_date = request.query.end_date;
            }

            const client = await fastify.pg.connect();
            const { rows } = await client.query("SELECT sd.get_measures_v100($1)", [
                JSON.stringify(filter),
            ]);
            client.release();

            const code = rows[0].get_measures_v100.code;
            if (code == 200) {
                reply
                    .type("application/json")
                    .code(code)
                    .send(rows[0].get_measures_v100.data);
            } else {
                reply.code(code).send(rows[0].get_measures_v100.status);
            }
        },
    });
    // GET sensor data from a patient
    fastify.route({
        method: "GET",
        url: "/data-sensor/latest",
        schema: listMeasuresSchema,
        handler: async(request, reply) => {
            const client = await fastify.pg.connect();
            const { rows } = await client.query(`SELECT JSON_AGG(s)
            FROM ( SELECT p.id_patient, COALESCE((SELECT JSON_AGG(t) FROM (
              SELECT _sd.measure_type, _sd.measure_value, _sd.date_generation
              FROM sd.v_measures_last_1hour _sd
              WHERE _sd.id_patient = p.id_patient ) t), '[]'::JSON) AS measures
            FROM becalm.patients p ) s`);
            client.release();
            reply.type("application/json").code(200).send(rows[0].json_agg);
        },
    });
    // POST sensor data for a patient
    fastify.route({
        method: "POST",
        url: "/data-sensor/:id_patient",
        schema: postMeasuresSchema,
        // this function is executed for every request before the handler is executed
        preHandler: async(request, reply) => {
            // e.g. check authentication
            //fastify.log.info("Called beforeHandler route POST /data-sensor/:id_patient");
        },
        handler: async(request, reply) => {
            const client = await fastify.pg.connect();
            const { rows } = await client.query("SELECT sd.post_measures($1, $2)", [
                request.params.id_patient,
                JSON.stringify(request.body),
            ]);
            client.release();

            const code = rows[0].post_measures.code;
            reply.code(code).send(rows[0].post_measures.status);
        },
    });
    done();
};