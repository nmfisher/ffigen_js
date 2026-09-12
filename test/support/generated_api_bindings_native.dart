// Conditional export of the ffigen-generated dart:ffi bindings. Used when the
// shared generated-API contract is compiled for the Dart VM.
export '../../example/lib/generated_bindings_ffi.g.dart'
    show
        UnreferencedEnum,
        compare_bytes,
        divide,
        fill_bytes,
        sum,
        sum_bytes,
        sum_with_typedef,
        verify_typed_data_alias,
        verify_typed_data_alignment,
        verify_typed_data_inputs_for_address_test,
        write_float32_for_address_test,
        write_float64_for_address_test,
        write_int16_for_address_test,
        write_int32_for_address_test,
        write_int64_for_address_test,
        write_uint16_for_address_test,
        write_uint32_for_address_test,
        write_uint8_for_address_test;
