
export function ensureValidString(value: string | undefined): string {
    if (value === undefined) 
        throw "invalid string"
    return value
}