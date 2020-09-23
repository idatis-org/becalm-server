// model of a
const measureSchema = {
    type: "object",
    properties: {
        measure_type: {
            type: "string",
        },
        measure_value: {
            type: "number",
        },
        date_generation: {
            type: "string",
        },
    },
};

// GET will list an array of device objects
const listMeasuresSchema = {
    summary: "Patient measures over time",
    description: "Array of measures by patient, ordered by descending time",
    response: {
        200: {
            type: "array",
            description: "List of measures taken from the given patient",
            items: {
                type: "object",
                properties: {
                    id_patient: {
                        description: "Patient ID number",
                        type: "number",
                    },
                    measures: {
                        type: "array",
                        description: "The measure values taken from the patient",
                        items: measureSchema,
                    },
                },
            },
        },
    },
};

// POST device - will return the full device schema, including ID
const postMeasuresSchema = {
    summary: "Create measures for a patient",
    description: "Array of measures taken for a patient to be recorded in the database",
    // id_device required to check the device has the right to post data for the patient
    querystring: {
        type: "object",
        required: ["id_device"],
        properties: {
            id_device: {
                description: "The id of the device posting the measure",
                type: "number",
            },
        },
        // with this flag other properties cannot be retrieved
        additionalProperties: false,
    },
    response: {
        201: {
            type: "object",
            properties: {
                code: {
                    type: "number",
                },
                status: {
                    type: "string",
                },
            },
        },
    },
};

module.exports = {
    measureSchema: measureSchema,
    listMeasuresSchema: listMeasuresSchema,
    postMeasuresSchema: postMeasuresSchema,
};