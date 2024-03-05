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

function(find_sign_tool result)
  find_program(
    sign_tool
    NAMES SignTool
    REQUIRED
  )

  set(${result} "${sign_tool}")

  return(PROPAGATE ${result})
endfunction()

function(add_appx_manifest target)
  set(one_value_keywords
    DESTINATION
    NAME
    VERSION
    PUBLISHER
    DISPLAY_NAME
    PUBLISHER_DISPLAY_NAME
    DESCRIPTION
  )

  set(multi_value_keywords
    UNVIRTUALIZED_PATHS
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" "${multi_value_keywords}"
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
  set(one_value_keywords
    DESTINATION
    LOGO
    ICON
    TARGET
    EXECUTABLE
  )

  set(multi_value_keywords
    RESOURCES
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" "${multi_value_keywords}"
  )

  if(NOT ARGV_DESTINATION)
    set(ARGV_DESTINATION Mapping.txt)
  endif()

  string(APPEND template "[Files]\n")

  if(ARGV_TARGET)
    set(ARGV_EXECUTABLE $<TARGET_FILE:${ARGV_TARGET}>)

    set(ARGV_EXECUTABLE_NAME $<TARGET_FILE_NAME:${ARGV_TARGET}>)
  else()
    cmake_path(ABSOLUTE_PATH ARGV_EXECUTABLE NORMALIZE)

    cmake_path(GET ARGV_EXECUTABLE FILENAME ARGV_EXECUTABLE_NAME)
  endif()

  string(APPEND template "\"${ARGV_EXECUTABLE}\" \"${ARGV_EXECUTABLE_NAME}\"\n")

  if(ARGV_LOGO)
    list(APPEND ARGV_RESOURCES FILE "${ARGV_LOGO}" "icon.png" )
  endif()

  if(ARGV_ICON)
    list(APPEND ARGV_RESOURCES FILE "${ARGV_ICON}" "icon.ico" )
  endif()

  while(TRUE)
    list(LENGTH ARGV_RESOURCES len)

    if(len LESS 3)
      break()
    endif()

    list(POP_FRONT ARGV_RESOURCES type from to)

    cmake_path(ABSOLUTE_PATH from NORMALIZE)

    if(NOT type MATCHES "FILE" AND NOT type MATCHES "DIR")
      continue()
    endif()

    string(APPEND template "\"${from}\" \"${to}\"\n")
  endwhile()

  file(GENERATE OUTPUT "${ARGV_DESTINATION}" CONTENT "${template}" NEWLINE_STYLE WIN32)
endfunction()

function(add_msix_package target)
  set(one_value_keywords
    DESTINATION
    MANIFEST
    MAPPING
  )

  set(multi_value_keywords
    DEPENDS
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" "${multi_value_keywords}"
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

  list(APPEND ARGV_DEPENDS  "${ARGV_MANIFEST}" "${ARGV_MAPPING}")

  find_make_appx(make_appx)

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

function(code_sign_msix_package target)
  set(one_value_keywords
    PATH
    SUBJECT_NAME
    THUMBPRINT
    TIMESTAMP
  )

  set(multi_value_keywords
    DEPENDS
  )

  cmake_parse_arguments(
    PARSE_ARGV 1 ARGV "" "${one_value_keywords}" "${multi_value_keywords}"
  )

  cmake_path(ABSOLUTE_PATH ARGV_PATH NORMALIZE)

  if(NOT ARGV_TIMESTAMP)
    set(ARGV_TIMESTAMP "http://timestamp.digicert.com")
  endif()

  if(ARGV_SUBJECT_NAME)
    list(APPEND args /n "${ARGV_SUBJECT_NAME}")
  endif()

  if(ARGV_THUMBPRINT)
    list(APPEND args /sha1 "${ARGV_THUMBPRINT}")
  endif()

  list(APPEND args /a /fd SHA256 /t "${ARGV_TIMESTAMP}")

  find_sign_tool(sign_tool)

  add_custom_target(
    ${target}
    ALL
    COMMAND ${sign_tool} sign ${args} "${ARGV_PATH}"
    DEPENDS ${ARGV_DEPENDS}
  )
endfunction()
