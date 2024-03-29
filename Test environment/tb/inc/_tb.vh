// Actuator control electronics
// ==============================================================================
// Описание:
// Данный файл с макросами определяет пути сохранения файлов, полученных в 
// результате HDL-моделирования.
// ==============================================================================

/*=============== Main Parameters ===============*/
    // To add output folder define ADD_OUT_FOLDER. Do not define for Icarus Verilog.
    // Better to define in simulator/compilator command string.
    `define ADD_OUT_FOLDER          1
    // Defines file path slash symbol to use.
    // Define SYSTEM_LINUX for simulation in Linux.
    // Define SYSTEM_WIN for simulation in Windows.
    `define SYSTEM_LINUX            1
    `define SYSTEM_WIN1

    `ifdef SYSTEM_LINUX
        `define OUT_FOLDER          "out/"
    `endif
    `ifdef SYSTEM_WIN
        `define OUT_FOLDER          "out\\"
    `endif

/*================ Files Naming ================*/
    `ifdef ADD_OUT_FOLDER
        `define DUMP_FILE_NAME      {`OUT_FOLDER, `TB_NAME, ".vcd"}
    `endif
    `ifndef ADD_OUT_FOLDER
        `define DUMP_FILE_NAME      {`TB_NAME, ".vcd"}
    `endif