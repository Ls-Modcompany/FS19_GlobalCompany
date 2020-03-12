
GC_DataTypeConverter = {}
g_company.dataTypeConverter = GC_DataTypeConverter

GC_DataTypeConverter.TYP_NIL = 0
GC_DataTypeConverter.TYP_BOOL = 1
GC_DataTypeConverter.TYP_FLOAT32 = 2
GC_DataTypeConverter.TYP_INT8 = 3
GC_DataTypeConverter.TYP_INT16 = 4
GC_DataTypeConverter.TYP_INT32 = 5
GC_DataTypeConverter.TYP_UINT8 = 6
GC_DataTypeConverter.TYP_UINT16 = 7
GC_DataTypeConverter.TYP_STRING = 8
GC_DataTypeConverter.TYP_TABLE = 9
GC_DataTypeConverter.TYP_NUMBER = 10


function GC_DataTypeConverter:getTypeByValue(value)
    if value == "true" or value == "True" or value == "TRUE" or value == "false" or value == "False" or value == "FALSE" then
        return GC_DataTypeConverter.TYP_BOOL
    elseif tonumber(value) ~= nil then
        return GC_DataTypeConverter.TYP_NUMBER
    else
        return GC_DataTypeConverter.TYP_STRING  
    end
end

function GC_DataTypeConverter:convertValueToDataTypeByValue(retValue, value)
    return GC_DataTypeConverter:convertTyp(retValue, GC_DataTypeConverter:getTypeByValue(value))  
end

function GC_DataTypeConverter:convertTyp(value, typ)    
    if typ == GC_DataTypeConverter.TYP_BOOL then
        return value == "true" or value == "True" or value == "TRUE" or value == "1"
    elseif  typ == GC_DataTypeConverter.TYP_STRING then
        return value
    elseif  typ == GC_DataTypeConverter.TYP_NUMBER then
        return tonumber(value)
    end
end

function GC_DataTypeConverter:parseValue(value)
    return GC_DataTypeConverter:convertTyp(value, GC_DataTypeConverter:getTypeByValue(value))
end

function GC_DataTypeConverter:parseParameters(parameters, delimter)
    local paras = g_company.utils.splitString(parameters, delimter);    
    local retParas = {}
    for _,para in pairs(paras) do
        table.insert(retParas, GC_DataTypeConverter:parseValue(para))
    end
    return retParas
end