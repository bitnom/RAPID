CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SEQUENCE IF NOT EXISTS rapid_sequence;

CREATE OR REPLACE FUNCTION public.generate_rapid() RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    timestamp_ms bigint;
    sequence_value bigint;
    timestamp_bytes BYTEA;
    counter_bytes BYTEA;
    random_bytes BYTEA;
BEGIN
    -- Get current timestamp in milliseconds
    timestamp_ms := (extract(epoch from now()) * 1000)::bigint;

    -- Lock the sequence to prevent concurrent modifications
    PERFORM pg_advisory_xact_lock(hashtext('rapid_sequence'));

    -- Get current value of the sequence
    SELECT last_value INTO sequence_value FROM rapid_sequence;

    -- If the sequence value doesn't match the current timestamp, reset it
    IF (sequence_value >> 22) != timestamp_ms THEN
        -- Set sequence to start at (timestamp_ms << 22) + 1
        PERFORM setval('rapid_sequence', (timestamp_ms << 22) + 1);
    END IF;

    -- Now get the next value from the sequence
    sequence_value := nextval('rapid_sequence');

    -- Release the lock immediately after we're done with the sequence
    PERFORM pg_advisory_unlock_all();

    -- Extract timestamp (6 bytes) and counter (2 bytes) from sequence_value
    timestamp_bytes := substring(int8send(sequence_value) from 1 for 6);
    counter_bytes := substring(int8send(sequence_value) from 7 for 2);

    -- Generate 8 random bytes
    random_bytes := gen_random_bytes(8);

    -- Combine timestamp, counter, and random bytes, encode as hex, and cast to UUID
    RETURN encode(timestamp_bytes || counter_bytes || random_bytes, 'hex')::uuid;
END;
$$;
