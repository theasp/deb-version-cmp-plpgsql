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
    -- Get current characters
    left_char := CASE WHEN left_pos <= length(left_part) THEN substring(left_part from left_pos for 1) ELSE '' END;
    right_char := CASE WHEN right_pos <= length(right_part) THEN substring(right_part from right_pos for 1) ELSE '' END;

    -- Handle end of both strings
    IF left_char = '' AND right_char = '' THEN
      RETURN 0;
    END IF;

    -- Handle tilde, which sorts before everything.
    IF left_char = '~' THEN
      IF right_char = '~' THEN
        -- Both are tildes, continue to the next character.
        left_pos := left_pos + 1;
        right_pos := right_pos + 1;
        CONTINUE;
      END IF;
      -- Left is tilde, right is not. Left is smaller.
      RETURN -1;
    END IF;
    IF right_char = '~' THEN
      -- Right is tilde, left is not. Right is smaller.
      RETURN 1;
    END IF;

    -- Handle end of one string. An empty part is smaller than any non-empty part (except tilde).
    IF left_char = '' THEN
      RETURN -1;
    END IF;
    IF right_char = '' THEN
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
    IF left_debian = '0' THEN
        left_debian := '';
    END IF;
    RAISE NOTICE 'Left version split: upstream=%, debian=%', left_upstream, left_debian;
  ELSE
    RAISE NOTICE 'Left version has no debian revision: upstream=%', left_upstream;
  END IF;

  pos := position('-' in reverse(right_upstream));
  IF pos > 0 THEN
    pos := length(right_upstream) - pos + 1;
    right_debian := substring(right_upstream from pos + 1);
    right_upstream := substring(right_upstream from 1 for pos - 1);
    IF right_debian = '0' THEN
        right_debian := '';
    END IF;
    RAISE NOTICE 'Right version split: upstream=%, debian=%', right_upstream, right_debian;
  ELSE
    RAISE NOTICE 'Right version has no debian revision: upstream=%', right_upstream;
  END IF;

  -- Compare upstream versions
  result := deb_version_cmp_parts(left_upstream, right_upstream);
  RAISE NOTICE 'Upstream comparison result: %', result;
  IF result != 0 THEN
    RETURN -result;
  END IF;

  -- Compare debian revisions
  result := deb_version_cmp_parts(left_debian, right_debian);
  RAISE NOTICE 'Debian revision comparison result: %', result;
  IF result != 0 THEN
    RETURN -result;
  END IF;

  RETURN 0;
END;
$function$;
