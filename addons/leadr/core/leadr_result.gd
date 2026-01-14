class_name LeadrResult
extends RefCounted
## Discriminated result type for LEADR API operations.
##
## All API methods return a LeadrResult. Check [member is_success] before accessing
## [member data] or [member error].
##
## Example:
## [codeblock]
## var result := await Leadr.get_boards()
## if result.is_success:
##     var page: LeadrPagedResult = result.data
##     for board in page.items:
##         print(board.name)
## else:
##     push_error(result.error.message)
## [/codeblock]

## Whether the operation succeeded.
var is_success: bool = false

## The result data on success. Type depends on the API method called.
var data: Variant = null

## Error details on failure.
var error: LeadrError = null


## Creates a successful result with the given data.
static func success(p_data: Variant) -> LeadrResult:
	var result := LeadrResult.new()
	result.is_success = true
	result.data = p_data
	return result


## Creates a failed result with the given error.
static func failure(p_error: LeadrError) -> LeadrResult:
	var result := LeadrResult.new()
	result.is_success = false
	result.error = p_error
	return result


## Creates a failed result with error details.
static func failure_from(p_status_code: int, p_code: String, p_message: String) -> LeadrResult:
	return failure(LeadrError.new(p_status_code, p_code, p_message))


## Returns the data if successful, otherwise returns the default value.
func unwrap_or(default: Variant) -> Variant:
	return data if is_success else default


## Returns the data if successful, otherwise returns null.
func unwrap_or_null() -> Variant:
	return data if is_success else null
