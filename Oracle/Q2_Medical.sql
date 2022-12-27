SELECT ''                                                                                                    ,
        a.owner                                                                                              ,
        DECODE (b.object_type, 'PACKAGE', CONCAT( CONCAT (b.object_name, '.'), a.object_name), b.object_name),
        DECODE(a.position, 0, 'RETURN_VALUE', a.argument_name)                                               ,
        DECODE(a.position, 0, 5, DECODE(a.in_out, 'IN', 1, 'IN/OUT', 2, 'OUT', 4))                           ,
        0                                                                                                    ,
        a.data_type                                                                                          ,
        a.data_precision                                                                                     ,
        a.data_length                                                                                        ,
        a.data_scale                                                                                         ,
        a.radix                                                                                              ,
        2                                                                                                    ,
        ''
FROM    ALL_ARGUMENTS a,
        ALL_OBJECTS b
WHERE
        (
                b.object_type    = 'PROCEDURE'
                OR b.object_type = 'FUNCTION'
        )
        AND b.object_id  = a.object_id
        AND a.data_level = 0
        AND a.OBJECT_NAME = 'EF_ATTRIBUTE_VAL_FROM_MOD_ATT' --ESCAPE '\'
ORDER BY 2,3,
        a.overload,
        a.position
