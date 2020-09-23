// model of a patient
const patientSchema = {
    type: "object",
    properties: {
        id_patient: {
            type: "number",
        },
        first_name_patient: {
            type: "string",
        },
        last_name_patient: {
            type: "string",
        },
        location_hospital: {
            type: "string",
        },
        location_place: {
            type: "string",
        },
        date_creation: {
            type: "string",
            format: "date-time",
        },
    },
};

// GET will list an array of device objects
const listPatientsSchema = {
    summary: "GET patients",
    description: "List of patients in the system",
    response: {
        200: {
            type: "array",
            items: {
                type: "object",
                properties: patientSchema,
            },
        },
    },
};

// POST device - will return the full device schema, including ID
const postPatientSchema = {
    summary: "Create a patient",
    description: "Data needed to create a new patient",
    params: {
        type: "object",
        properties: {
            name: {
                type: "number",
            },
            type_device: {
                type: "string",
            },
            model_device: {
                type: "string",
            },
            version_device: {
                type: "string",
            },
            location_hospital: {
                type: "string",
            },
            location_place: {
                type: "string",
            },
        },
        response: {
            201: {
                type: "object",
                properties: patientSchema,
            },
        },
    },
};

module.exports = {
    patientSchema: patientSchema,
    listPatientsSchema: listPatientsSchema,
    postDeviceSchema: postPatientSchema,
};