// model of a device
const deviceSchema = {
    type: "object",
    properties: {
        id_device: {
            type: "number",
        },
        name_device: {
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
        ip_device: {
            type: "string",
            format: "ipv4"
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
const listDevicesSchema = {
    summary: "GET devices",
    description: "List of patient monitoring devices",
    response: {
        200: {
            type: "array",
            items: {
                type: "object",
                properties: deviceSchema,
            },
        },
    },
};

// POST device - will return the full device schema, including ID
const postDeviceSchema = {
    summary: "Create a device",
    description: "Data needed to create a new device",
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
                properties: deviceSchema,
            },
        },
    },
};

module.exports = {
    deviceSchema: deviceSchema,
    listDevicesSchema: listDevicesSchema,
    postDeviceSchema: postDeviceSchema,
};