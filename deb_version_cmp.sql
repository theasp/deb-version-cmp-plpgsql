CREATE OR REPLACE FUNCTION public.deb_version_cmp_parts(left_part text, right_part text)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE
  left_pos integer := 1;
  right_pos integer := 1;
  left_char text;
  right_char text;
  left_num text := '';
  right_num text := '';
BEGIN
  RAISE NOTICE 'Comparing parts: left=%, right=%', left_part, right_part;

  LOOP
    -- Handle end of strings
    IF left_pos > length(left_part) AND right_pos > length(right_part) THEN
      RETURN 0;
    END IF;

    -- Get current characters
    left_char := CASE WHEN left_pos <= length(left_part) THEN substring(left_part from left_pos for 1) ELSE '' END;
    right_char := CASE WHEN right_pos <= length(right_part) THEN substring(right_part from right_pos for 1) ELSE '' END;

    -- Special handling for tilde
    IF left_char = '~' OR right_char = '~' THEN
      IF left_char = '~' AND right_char != '~' THEN
        RETURN -1; -- tilde sorts before everything
      ELSIF left_char != '~' AND right_char = '~' THEN
        RETURN 1;
      END IF;
      left_pos := left_pos + 1;
      right_pos := right_pos + 1;
      CONTINUE;
    END IF;

    -- Handle end of strings after tilde check
    IF left_char = '' AND right_char = '' THEN
      RETURN 0;
    ELSIF left_char = '' THEN
      RETURN -1; -- shorter string sorts first
    ELSIF right_char = '' THEN
      RETURN 1;
    END IF;

    -- Compare digit sequences
    IF left_char ~ '[0-9]' OR right_char ~ '[0-9]' THEN
      -- If one side is not a digit, it sorts after digits
      IF NOT left_char ~ '[0-9]' THEN
        RETURN 1;
      ELSIF NOT right_char ~ '[0-9]' THEN
        RETURN -1;
      END IF;

      left_num := '';
      right_num := '';

      -- Collect digits
      WHILE left_pos <= length(left_part) AND substring(left_part from left_pos for 1) ~ '[0-9]' LOOP
        left_num := left_num || substring(left_part from left_pos for 1);
        left_pos := left_pos + 1;
      END LOOP;

      WHILE right_pos <= length(right_part) AND substring(right_part from right_pos for 1) ~ '[0-9]' LOOP
        right_num := right_num || substring(right_part from right_pos for 1);
        right_pos := right_pos + 1;
      END LOOP;

      -- Remove leading zeros
      left_num := ltrim(left_num, '0');
      right_num := ltrim(right_num, '0');
      IF left_num = '' THEN
        left_num := '0';
      END IF;
      IF right_num = '' THEN
        right_num := '0';
      END IF;

      IF left_num::bigint < right_num::bigint THEN
        RETURN -1;
      ELSIF left_num::bigint > right_num::bigint THEN
        RETURN 1;
      END IF;
      CONTINUE;
    END IF;

    -- Compare non-digits (letters sort before non-letters)
    IF left_char != right_char THEN
      IF left_char ~ '[A-Za-z]' AND NOT right_char ~ '[A-Za-z]' THEN
        RETURN -1;
      ELSIF NOT left_char ~ '[A-Za-z]' AND right_char ~ '[A-Za-z]' THEN
        RETURN 1;
      ELSE
        RETURN CASE WHEN left_char < right_char THEN -1 ELSE 1 END;
      END IF;
    END IF;

    left_pos := left_pos + 1;
    right_pos := right_pos + 1;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION deb_version_cmp_segment(left_segment text, right_segment text)
RETURNS integer
AS $$
DECLARE
  left_pos integer := 1;
  right_pos integer := 1;
  left_len integer;
  right_len integer;
  left_char text;
  right_char text;
  left_num text;
  right_num text;
BEGIN
  left_len := length(left_segment);
  right_len := length(right_segment);

  RAISE NOTICE 'Comparing individual segments: left=%, right=%', left_segment, right_segment;

  LOOP
    -- Handle end of segments
    IF left_pos > left_len AND right_pos > right_len THEN
      RETURN 0;
    END IF;

    -- Get current characters
    left_char := CASE WHEN left_pos <= left_len THEN substring(left_segment from left_pos for 1) ELSE '' END;
    right_char := CASE WHEN right_pos <= right_len THEN substring(right_segment from right_pos for 1) ELSE '' END;

    RAISE NOTICE 'Comparing chars at pos %,%: left=%, right=%', left_pos, right_pos, left_char, right_char;

    -- Handle tilde with highest priority
    IF left_char = '~' OR right_char = '~' THEN
      IF left_char = '~' AND right_char != '~' THEN
        RETURN -1;
      ELSIF left_char != '~' AND right_char = '~' THEN
        RETURN 1;
      ELSE
        left_pos := left_pos + 1;
        right_pos := right_pos + 1;
        CONTINUE;
      END IF;
    END IF;

    -- Handle segment endings after tilde check
    IF left_char = '' AND right_char = '' THEN
      RETURN 0;
    ELSIF left_char = '' THEN
      RETURN -1;
    ELSIF right_char = '' THEN
      RETURN 1;
    END IF;

    -- Handle digits
    IF left_char ~ '[0-9]' OR right_char ~ '[0-9]' THEN
      left_num := '';
      right_num := '';

      -- Collect digits
      WHILE left_pos <= left_len AND substring(left_segment from left_pos for 1) ~ '[0-9]' LOOP
        left_num := left_num || substring(left_segment from left_pos for 1);
        left_pos := left_pos + 1;
      END LOOP;

      WHILE right_pos <= right_len AND substring(right_segment from right_pos for 1) ~ '[0-9]' LOOP
        right_num := right_num || substring(right_segment from right_pos for 1);
        right_pos := right_pos + 1;
      END LOOP;

      -- Handle empty numbers
      IF left_num = '' THEN
        left_num := '0';
      END IF;
      IF right_num = '' THEN
        right_num := '0';
      END IF;

      RAISE NOTICE 'Comparing numbers: left=%, right=%', left_num, right_num;

      -- Compare numbers
      IF left_num::bigint < right_num::bigint THEN
        RETURN -1;
      ELSIF left_num::bigint > right_num::bigint THEN
        RETURN 1;
      END IF;
      CONTINUE;
    END IF;

    -- Compare non-digits 
    IF left_char != right_char THEN
      -- Prioritize letters over other non-digit characters
      IF left_char ~ '[A-Za-z]' AND NOT right_char ~ '[A-Za-z]' THEN
        RETURN -1; -- letters before non-letters
      ELSIF NOT left_char ~ '[A-Za-z]' AND right_char ~ '[A-Za-z]' THEN
        RETURN 1;  -- non-letters after letters
      END IF;

      -- If both are letters or both are non-letters, compare lexicographically
      RETURN CASE WHEN left_char < right_char THEN -1 ELSE 1 END; 
    END IF;

    left_pos := left_pos + 1;
    right_pos := right_pos + 1;
  END LOOP;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.deb_version_cmp_revision(left_debian text, right_debian text, OUT left_parts text[], OUT right_parts text[])
RETURNS record
LANGUAGE plpgsql
AS $function$
DECLARE
  result integer;
  i integer;
BEGIN
  RAISE NOTICE 'Original Debian revisions: left=%, right=%', left_debian, right_debian;

  -- Split into parts based on text/numeric boundaries, preserving special characters
  left_parts := regexp_split_to_array(left_debian, '(?=\.?[0-9]+|[a-zA-Z]+|\+|-|~)');
  right_parts := regexp_split_to_array(right_debian, '(?=\.?[0-9]+|[a-zA-Z]+|\+|-|~)');

  RAISE NOTICE 'Debian revision parts: left=%, right=%', left_parts, right_parts;

  i := 1;
  WHILE i <= greatest(array_length(left_parts, 1), array_length(right_parts, 1)) LOOP
    RAISE NOTICE 'Comparing part %: left=%, right=%', i, left_parts[i], right_parts[i];

    result := deb_version_cmp_segment(left_parts[i], right_parts[i]);
    RAISE NOTICE 'Result of deb_version_cmp_segment: %', result;

    IF result != 0 THEN
      RETURN;  -- Return the result directly, without inverting
    END IF;

    i := i + 1;
  END LOOP;

  RETURN;
END;
$function$;

CREATE OR REPLACE FUNCTION public.deb_version_cmp(left_version text, right_version text)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE
  left_epoch text := '0';
  right_epoch text := '0';
  left_upstream text;
  right_upstream text;
  left_debian text := '';
  right_debian text := '';
  pos integer;
  result integer;
  left_parts text[];
  right_parts text[];
  debian_result record;
BEGIN
  -- Handle epochs
  IF left_version ~ ':' THEN
    left_epoch := split_part(left_version, ':', 1);
    left_upstream := split_part(left_version, ':', 2);
  ELSE
    left_upstream := left_version;
  END IF;

  IF right_version ~ ':' THEN
    right_epoch := split_part(right_version, ':', 1);
    right_upstream := split_part(right_version, ':', 2);
  ELSE
    right_upstream := right_version;
  END IF;

  -- Compare epochs first
  result := deb_version_cmp_parts(left_epoch, right_epoch);
  IF result != 0 THEN
    RETURN -result; -- Invert for correct comparison
  END IF;

  -- Parse debian revision
  pos := position('-' in reverse(left_upstream));
  IF pos > 0 THEN
    pos := length(left_upstream) - pos + 1;
    left_debian := substring(left_upstream from pos + 1);
    left_upstream := substring(left_upstream from 1 for pos - 1);
    RAISE NOTICE 'Left version split: upstream=%, debian=%', left_upstream, left_debian;
  ELSE
    RAISE NOTICE 'Left version has no debian revision: upstream=%', left_upstream;
  END IF;

  pos := position('-' in reverse(right_upstream));
  IF pos > 0 THEN
    pos := length(right_upstream) - pos + 1;
    right_debian := substring(right_upstream from pos + 1);
    right_upstream := substring(right_upstream from 1 for pos - 1);
    RAISE NOTICE 'Right version split: upstream=%, debian=%', right_upstream, right_debian;
  ELSE
    RAISE NOTICE 'Right version has no debian revision: upstream=%', right_upstream;
  END IF;

  -- Compare upstream versions
  result := deb_version_cmp_parts(left_upstream, right_upstream);
  RAISE NOTICE 'Upstream comparison result: %', result;

  -- If upstream versions are equal, compare debian revisions
  IF result = 0 AND (left_debian != '' OR right_debian != '') THEN
    -- For debian revisions, we need to handle ubuntu version components
    SELECT debian_result.left_parts, debian_result.right_parts, deb_version_cmp_segment(left_debian, right_debian)
    INTO left_parts, right_parts, result  -- Assign the result of deb_version_cmp_segment to result
    FROM deb_version_cmp_revision(left_debian, right_debian) AS debian_result; -- Use alias for clarity

    RAISE NOTICE 'Debian revision comparison result: %', result;

    -- Check if the last comparison was between numeric segments
    IF left_parts[array_length(left_parts, 1)] ~ '^[0-9]+$' AND right_parts[array_length(right_parts, 1)] ~ '^[0-9]+$' THEN
      RETURN -result;  -- Invert the result only if the last comparison was numeric
    ELSE
      RETURN result;   -- Otherwise, use the result directly
    END IF;
  END IF;

  -- Invert the result to match the desired behavior (only for upstream comparison)
  RETURN -result;
END;
$function$;
