/*
# This file is part of becalm-server
# https://github.com/idatis-org/becalm-server
# Copyright: Copyright (C) 2020 Felipe Santi <felipe.santig@gmail.com>
# License:   Apache License Version 2.0, January 2004
#            The full text of the Apache License is available here
#            http://www.apache.org/licenses/
*/

const listDevicesSchema = require("./schema");

// GET device data
module.exports = (fastify, options, done) => {
  fastify.route({
    method: "GET",
    url: "/devices",
    prefixTrailingSlash: "both",
    schema: {
      listDevicesSchema,
    },
    handler: async (request, reply) => {
      const client = await fastify.pg.connect();
      const {
        rows,
      } = await client.query(`SELECT json_agg(s) FROM (SELECT d.id_device, d.name_device,
                d.type_device, d.model_device, d.version_device, d.location_hospital, d.ip_device, 
                d.location_place, d.date_creation FROM sd.v_devices d) s;`);
      client.release();

      reply.type("application/json").code(200).send(rows[0].json_agg);
    },
  });
  done();
};
