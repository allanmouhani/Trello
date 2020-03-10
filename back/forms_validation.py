import re


def validate_name(name):
    name_length = len(name)

    if name_length < 3:
        return (False, '''The name provided is too short, should be 3 to 25
                       characters ''')
    if name_length > 25:
        return (False, '''The name provided is too long, should be 3 to 25
                       characters ''')

    if re.match(r"^[a-zA-Z]([ ._-]?[a-zA-Z0-9]+){2,25}$", name):
        return (True, None)
    return (False, 'Invalid name !!')


def validate_email(email):

    if not email:
        return (False, ''' Oops! Looks like you did not provide an email ''')

    if re.match(r"(^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$)", email):
        return (True, None)
    return (False, 'Invalid email address !!')


def validate_signup(name, email):
    is_name_valid, status = validate_name(name)

    if is_name_valid:
        _, status = validate_email(email)
    return status
