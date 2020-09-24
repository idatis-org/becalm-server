/*
# This file is part of becalm-server
# https://github.com/idatis-org/becalm-server
# Copyright: Copyright (C) 2020 Felipe Santi <felipe.santig@gmail.com>
# License:   Apache License Version 2.0, January 2004
#            The full text of the Apache License is available here
#            http://www.apache.org/licenses/
*/

const listPatientsSchema = require("./schema");

// GET patients data
module.exports = (fastify, options, done) => {
  fastify.route({
    method: "GET",
    url: "/patients",
    prefixTrailingSlash: "both",
    schema: {
      listPatientsSchema,
    },
    handler: async (request, reply) => {
      const client = await fastify.pg.connect();
      const { rows } = await client.query(`SELECT json_agg(s) FROM (
                SELECT 
                  p.id_patient,
                  p.first_name_patient,
                  p.last_name_patient,
                  p.location_hospital,
                  p.location_place,
                  p.date_creation
                FROM sd.v_patients p) s;`);
      client.release();
      reply.type("application/json").code(200).send(rows[0].json_agg);
    },
  });
  done();
};
