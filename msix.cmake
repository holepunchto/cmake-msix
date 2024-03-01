set(msix_module_root ${CMAKE_CURRENT_LIST_DIR})

function(find_make_appx result)
  find_program(
    make_appx
    NAMES MakeAppx
    REQUIRED
  )

  set(${result} "${make_appx}")

  return(PROPAGATE ${result})
endfunction()

function(add_appx_manifest target)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "DESTINATION;NAME;VERSION;PUBLISHER;DISPLAY_NAME;PUBLISHER_DISPLAY_NAME;DESCRIPTION" "UNVIRTUALIZED_PATHS"
  )

  if(NOT ARGV_DESTINATION)
    set(ARGV_DESTINATION AppxManifest.xml)
  endif()

  if(NOT DEFINED ARGV_PUBLISHER)
    set(ARGV_PUBLISHER "CN=AppModelSamples, OID.2.25.311729368913984317654407730594956997722=1")
  endif()

  if(NOT DEFINED ARGV_DISPLAY_NAME)
    set(ARGV_DISPLAY_NAME "${ARGV_NAME}")
  endif()

  list(TRANSFORM ARGV_UNVIRTUALIZED_PATHS PREPEND "<virtualization:ExcludedDirectory>")

  list(TRANSFORM ARGV_UNVIRTUALIZED_PATHS APPEND "</virtualization:ExcludedDirectory>")

  list(JOIN ARGV_UNVIRTUALIZED_PATHS "" ARGV_UNVIRTUALIZED_PATHS)

  file(READ "${msix_module_root}/AppxManifest.xml" template)

  string(CONFIGURE "${template}" template)

  file(GENERATE OUTPUT "${ARGV_DESTINATION}" CONTENT "${template}" NEWLINE_STYLE WIN32)
endfunction()

function(add_appx_mapping target)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "DESTINATION;NAME;LOGO;ICON;TARGET;EXECUTABLE" ""
  )

  if(NOT ARGV_DESTINATION)
    set(ARGV_DESTINATION Mapping.txt)
  endif()

  string(APPEND template "[Files]\n")

  if(ARGV_TARGET)
    set(ARGV_EXECUTABLE $<TARGET_FILE:${ARGV_TARGET}>)
  endif()

  string(APPEND template "\"${ARGV_EXECUTABLE}\" \"${ARGV_NAME}.exe\"\n")

  if(ARGV_LOGO)
    cmake_path(ABSOLUTE_PATH ARGV_LOGO NORMALIZE)

    string(APPEND template "\"${ARGV_LOGO}\" \"icon.png\"\n")
  endif()

  if(ARGV_ICON)
    cmake_path(ABSOLUTE_PATH ARGV_ICON NORMALIZE)

    string(APPEND template "\"${ARGV_ICON}\" \"icon.ico\"\n")
  endif()

  file(GENERATE OUTPUT "${ARGV_DESTINATION}" CONTENT "${template}" NEWLINE_STYLE WIN32)
endfunction()

function(add_msix_package target)
  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "DESTINATION;MANIFEST;MAPPING;DEPENDS" ""
  )

  cmake_path(ABSOLUTE_PATH ARGV_DESTINATION BASE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}" NORMALIZE)

  cmake_path(GET ARGV_DESTINATION PARENT_PATH base)

  if(ARGV_MANIFEST)
    cmake_path(ABSOLUTE_PATH ARGV_MANIFEST NORMALIZE)
  else()
    cmake_path(APPEND base "AppxManifest.xml" OUTPUT_VARIABLE ARGV_MANIFEST)
  endif()

  if(ARGV_MAPPING)
    cmake_path(ABSOLUTE_PATH ARGV_MAPPING NORMALIZE)
  else()
    cmake_path(APPEND base "Mapping.txt" OUTPUT_VARIABLE ARGV_MAPPING)
  endif()

  find_make_appx(make_appx)

  list(APPEND ARGV_DEPENDS  "${ARGV_MANIFEST}" "${ARGV_MAPPING}")

  list(APPEND commands
    COMMAND "${make_appx}" pack /o /m "${ARGV_MANIFEST}" /f "${ARGV_MAPPING}" /p "${ARGV_DESTINATION}"
  )

  add_custom_target(
    ${target}
    ALL
    ${commands}
    DEPENDS ${ARGV_DEPENDS}
  )
endfunction()
