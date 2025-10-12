defmodule Parsely.JapaneseOCRService do
  @moduledoc """
  Japanese-specific OCR parsing service that mirrors the English logic exactly.
  """

  @doc """
  Parses Japanese business card text using the same logic as English parsing.
  """
  def parse_business_card_text(text) do
    IO.puts("=== JAPANESE OCR SERVICE: Parsing business card text ===")

    # Split into lines and normalize (same as English)
    lines = text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    IO.puts("Japanese text lines:")
    Enum.with_index(lines, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Line #{index}: '#{line}'")
    end)

    # Step 1: Extract email and phone (easily identified)
    IO.puts("=== STEP 1: EXTRACTING EMAIL AND PHONE ===")
    email = find_email_japanese(text)
    phone = Parsely.OCRService.find_phone(text)  # Reuse English phone function since numbers are universal

    # Safely print extracted values
    safe_email = if email do
      email
      |> :unicode.characters_to_binary(:utf8, :latin1)
      |> String.replace(~r/[^\x20-\x7E]/, "?")
    else
      "nil"
    end
    safe_phone = if phone do
      phone
      |> :unicode.characters_to_binary(:utf8, :latin1)
      |> String.replace(~r/[^\x20-\x7E]/, "?")
    else
      "nil"
    end
    IO.puts("Extracted email: #{safe_email}")
    IO.puts("Extracted phone: #{safe_phone}")

    # Step 2: Extract position based on scoring (Japanese version)
    IO.puts("=== STEP 2: EXTRACTING POSITION ===")
    position = find_position_by_scoring(text, email, phone)

    # Step 3: Extract name based on format (capitalization) (Japanese version)
    IO.puts("=== STEP 3: EXTRACTING NAME BY FORMAT ===")
    name = find_name_by_format(text, email, phone, position)

    # Step 4: Extract company using keywords and remaining lines (Japanese version)
    IO.puts("=== STEP 4: EXTRACTING COMPANY BY KEYWORDS ===")
    company = find_company_by_keywords(text, email, phone, position, name)

    result = %{
      name: name,
      email: email,
      phone: phone,
      company: company,
      position: position,
      raw_text: text
    }

    IO.puts("Japanese parsing results:")
    IO.puts("  Name: #{name}")
    IO.puts("  Company: #{company}")
    IO.puts("  Position: #{position}")
    IO.puts("  Email: #{email} (from universal function)")
    IO.puts("  Phone: #{phone} (from universal function)")

    {:ok, result}
  end

  defp find_email_japanese(text) do
    IO.puts("=== FINDING JAPANESE EMAIL ===")

    try do
      # First, try to find any line with @ symbol (most aggressive approach)
      lines_with_at = text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&String.contains?(&1, "@"))

      IO.puts("Lines containing @ symbol: #{inspect(lines_with_at)}")

      # Try to extract email from lines with @
      potential_email = Enum.find_value(lines_with_at, fn line ->
        IO.puts("Processing line with @: '#{line}'")
        # Clean up the line and try to extract email
        cleaned_line = line
        |> String.replace(~r/\s+/, "")  # Remove all whitespace
        |> String.replace(~r/\[at\]/, "@")  # Replace [at] with @
        |> String.replace(~r/\[dot\]/, ".")  # Replace [dot] with .
        |> String.replace(~r/[«»]/, "")  # Remove guillemets
        |> String.replace(~r/鹵/, "l")  # Common OCR corruption: 鹵 -> l
        |> String.replace(~r/ー/, "-")  # Japanese long vowel mark: ー -> -
        |> String.replace("ⅰ", "i")
        |> String.replace("ⅱ", "ii")
        |> String.replace("ⅲ", "iii")
        |> String.replace("ⅳ", "iv")
        |> String.replace("ⅴ", "v")
        |> String.replace("ⅵ", "vi")
        |> String.replace("ⅶ", "vii")
        |> String.replace("ⅷ", "viii")
        |> String.replace("ⅸ", "ix")
        |> String.replace("ⅹ", "x")
        |> String.replace("ぉ", "o")  # Japanese hiragana corruption
        |> String.replace("軒", "n")  # Japanese kanji corruption
        |> String.replace("眠", "m")  # Japanese kanji corruption
        |> String.replace("離", "l")  # Japanese kanji corruption
        |> String.replace("僑", "g")  # Japanese kanji corruption
        |> String.replace("配", "p")  # Japanese kanji corruption
        |> String.replace("費", "f")  # Japanese kanji corruption
        |> String.replace("翹", "n")  # Japanese kanji corruption (翹 -> n)
        |> String.replace("は", "a")  # Japanese hiragana corruption (は -> a)
        |> String.replace("、", "")   # Remove Japanese comma
        |> String.replace("・", "")   # Remove Japanese middle dot
        |> String.replace("(", "")   # Remove parentheses
        |> String.replace(")", "")   # Remove parentheses
        |> String.replace("血", "c")  # Japanese kanji corruption (血 -> c)
        |> String.replace("日", "d")  # Japanese kanji corruption (日 -> d)
        |> String.replace("恥", "c")  # Japanese kanji corruption (恥 -> c)
        |> String.replace("部", "b")  # Japanese kanji corruption (部 -> b)
        |> String.replace("区", "u")  # Japanese kanji corruption (区 -> u)
        |> String.replace(~r/[^\w@.-]/, "") # Remove any remaining non-alphanumeric chars except @, ., -

        IO.puts("Cleaned line: '#{cleaned_line}'")

        # Try to match standard email pattern on cleaned line
        case Regex.run(~r/[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/, cleaned_line) do
          [email | _] ->
            IO.puts("Found email after cleaning: '#{email}'")
            email
          nil ->
            IO.puts("No valid email pattern found in cleaned line")
            nil
        end
      end)

      # If we found an email from @ lines, return it
      if potential_email do
        IO.puts("Extracted email from @ line: '#{potential_email}'")
        potential_email
      else
        # Fallback to original patterns
        email_patterns = [
          ~r/[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/, # Standard email
          ~r/[A-Za-z0-9._%+\-鹵ーⅰⅱⅲⅳⅴⅵⅶⅷⅸⅹ翹は]+@[A-Za-z0-9.\-鹵ーⅰⅱⅲⅳⅴⅵⅶⅷⅸⅹ翹は]+\.[A-Za-z]{2,}/, # Heavily corrupted email
          ~r/\([^)]*@[^)]*\)/, # Email in parentheses
          ~r/メール[:\s]*([A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})/, # Japanese "メール:" prefix
          ~r/メールアドレス[:\s]*([A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})/, # Japanese "メールアドレス:" prefix
          ~r/E-mail[:\s]*([A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})/, # E-mail prefix
          ~r/Email[:\s]*([A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})/, # Email prefix
          # Pattern for heavily corrupted emails like "mitdcreinⅱ翹はcdは、・i、.ed"
          ~r/[A-Za-z0-9._%+\-ⅰⅱⅲⅳⅴⅵⅶⅷⅸⅹ翹は、・]+@[A-Za-z0-9.\-ⅰⅱⅲⅳⅴⅵⅶⅷⅸⅹ翹は、・]+\.[A-Za-z]{2,}/,
        ]

        Enum.find_value(email_patterns, fn pattern ->
        case Regex.run(pattern, text) do
          [email | _] ->
            # Clean up the email - handle corrupted OCR characters
            cleaned_email = email
            |> String.replace(~r/\s+/, "")  # Remove all whitespace
            |> String.replace(~r/\[at\]/, "@")  # Replace [at] with @
            |> String.replace(~r/\[dot\]/, ".")  # Replace [dot] with .
            |> String.replace(~r/[«»]/, "")  # Remove guillemets
            |> String.replace(~r/鹵/, "l")  # Common OCR corruption: 鹵 -> l
            |> String.replace(~r/ー/, "-")  # Japanese long vowel mark: ー -> -
            |> String.replace("ⅰ", "i")
            |> String.replace("ⅱ", "ii")
            |> String.replace("ⅲ", "iii")
            |> String.replace("ⅳ", "iv")
            |> String.replace("ⅴ", "v")
            |> String.replace("ⅵ", "vi")
            |> String.replace("ⅶ", "vii")
            |> String.replace("ⅷ", "viii")
            |> String.replace("ⅸ", "ix")
            |> String.replace("ⅹ", "x")
            |> String.replace("ぉ", "o")  # Japanese hiragana corruption
            |> String.replace("軒", "n")  # Japanese kanji corruption
            |> String.replace("眠", "m")  # Japanese kanji corruption
            |> String.replace("離", "l")  # Japanese kanji corruption
            |> String.replace("僑", "g")  # Japanese kanji corruption
            |> String.replace("配", "p")  # Japanese kanji corruption
            |> String.replace("費", "f")  # Japanese kanji corruption
            |> String.replace("翹", "n")  # Japanese kanji corruption (翹 -> n)
            |> String.replace("は", "a")  # Japanese hiragana corruption (は -> a)
            |> String.replace("、", "")   # Remove Japanese comma
            |> String.replace("・", "")   # Remove Japanese middle dot
            |> String.replace("(", "")   # Remove parentheses
            |> String.replace(")", "")   # Remove parentheses
            |> String.replace(~r/[^\w@.-]/, "") # Remove any remaining non-alphanumeric chars except @, ., -
            |> String.trim()

            # Validate that it still looks like an email after cleaning
            if String.contains?(cleaned_email, "@") and String.contains?(cleaned_email, ".") do
              # Safely print email by converting to binary and replacing non-printable chars
              safe_email = cleaned_email
              |> :unicode.characters_to_binary(:utf8, :latin1)
              |> String.replace(~r/[^\x20-\x7E]/, "?")
              IO.puts("Found email: #{safe_email}")
              cleaned_email
            else
              nil
            end
          nil -> nil
        end
        end) || (IO.puts("No email found"); nil)
      end
    rescue
      error ->
        IO.puts("Error in email extraction: #{inspect(error)}")
        nil
    end
  end

  defp find_position_by_scoring(text, _email, _phone) do
    IO.puts("=== FINDING JAPANESE POSITION BY SCORING ===")

    # Split into lines and normalize
    lines =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    IO.puts("All lines for position analysis:")
    Enum.with_index(lines, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Line #{index}: '#{line}'")
    end)

    # Common job titles/positions (Japanese equivalents)
    position_keywords = [
      # English terms (for mixed language cards)
      "engineer", "developer", "manager", "director", "founder", "cofounder", "chief", "officer",
      "marketing", "sales", "product", "design", "designer", "accounting", "consultant", "analyst",
      "specialist", "coordinator", "supervisor", "lead", "senior", "junior", "principal",
      "president", "vice", "ceo", "cto", "cfo", "coo", "vp", "executive",
      "ambassador", "consul", "consul general", "deputy consul",
      "press attache", "cultural attache", "commercial attache",
      "first secretary", "second secretary", "third secretary",
      "attaché", "attaché", "attaché", "attaché",
      "minister", "counselor", "embassy", "embassy",
      "diplomatic", "diplomatic officer", "foreign service",
      "trade commissioner", "economic officer", "political officer",
      "public affairs officer", "protocol officer", "advisor", "operations manager",
      # Japanese equivalents
      "エンジニア", "デベロッパー", "マネージャー", "ディレクター", "ファウンダー", "チーフ", "オフィサー",
      "マーケティング", "セールス", "プロダクト", "デザイン", "デザイナー", "アカウンティング", "コンサルタント", "アナリスト",
      "スペシャリスト", "コーディネーター", "スーパーバイザー", "リード", "シニア", "ジュニア", "プリンシパル",
      "プレジデント", "バイス", "CEO", "CTO", "CFO", "COO", "VP", "エグゼクティブ",
      "アンバサダー", "領事", "領事総領事", "副領事",
      "プレスアタッシェ", "文化アタッシェ", "商務アタッシェ",
      "一等書記官", "二等書記官", "三等書記官",
      "アタッシェ", "アタッシェ", "アタッシェ", "アタッシェ",
      "大臣", "カウンセラー", "大使館", "大使館",
      "外交", "外交官", "外務省",
      "貿易コミッショナー", "経済官", "政治官",
      "広報官", "儀典官",
      "アドバイザー", "オペレーションズマネージャー", "アドバイザー", "オペレーションズ", "マネージャー",
      "技術者", "開発者", "管理者", "取締役", "創設者", "共同創設者", "最高責任者", "役員",
      "営業", "販売", "製品", "設計", "会計", "顧問", "専門家", "調整者", "監督者", "上級", "下級", "主任",
      "社長", "副社長", "最高経営責任者", "最高技術責任者", "最高財務責任者", "最高執行責任者", "副社長", "執行役員",
      "大使", "総領事", "領事", "副領事",
      "報道担当", "文化担当", "商務担当",
      "一等書記官", "二等書記官", "三等書記官",
      "アタッシェ", "アタッシェ", "アタッシェ", "アタッシェ",
      "大臣", "参事官", "大使館", "大使館",
      "外交", "外交官", "外務省",
      "貿易委員", "経済担当官", "政治担当官",
      "広報担当官", "儀典担当官",
      "アドバイザー", "運営管理者", "運営マネージャー"
    ]

    # Helper predicates (mirror English exactly)
    has_letters? = fn line -> Regex.match?(~r/[A-Za-z\p{Hiragana}\p{Katakana}\p{Han}]/u, line) end
    is_email_line? = fn line -> String.contains?(line, "@") end
    is_phone_line? = fn line -> Regex.match?(~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/, line) end
    is_urlish? = fn line ->
      down = String.downcase(line)
      String.contains?(down, "www") or String.contains?(down, "http")
    end

    # Filter out obvious non-position lines (mirror English exactly)
    IO.puts("Filtering out email, phone, and non-letter lines...")
    filtered_lines = lines
    |> Enum.reject(fn line ->
      is_email_line?.(line) or is_phone_line?.(line) or not has_letters?.(line) or is_urlish?.(line)
    end)

    IO.puts("Remaining lines after filtering:")
    Enum.with_index(filtered_lines, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Filtered line #{index}: '#{line}'")
    end)

    # Score each line as a position candidate (mirror English exactly)
    position_candidates =
      filtered_lines
      |> Enum.map(fn line ->
        down = String.downcase(line)
        contains_keywords = Enum.any?(position_keywords, &String.contains?(down, &1))
        looks_like_title = Regex.match?(~r/^[A-Z\p{Hiragana}\p{Katakana}\p{Han}][A-Za-z\p{Hiragana}\p{Katakana}\p{Han}\s&.-]{2,40}$/u, line) and
                            length(String.split(line, ~r/\s+/, trim: true)) in 1..3

        IO.puts("  Analyzing line: '#{line}'")
        IO.puts("    Contains keywords: #{contains_keywords}")
        IO.puts("    Looks like title: #{looks_like_title}")

        score = 0
        score = if contains_keywords, do: score + 5, else: score
        score = if looks_like_title, do: score + 1, else: score

        {score, line}
      end)
      |> Enum.filter(fn {score, _line} -> score > 0 end)
      |> Enum.sort_by(fn {score, _line} -> -score end)
      |> Enum.map(fn {_score, line} -> line end)

    IO.puts("Position candidates (sorted by score):")
    Enum.with_index(position_candidates, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Candidate #{index}: '#{line}'")
    end)

    case position_candidates do
      [position | _] ->
        IO.puts("Selected position: '#{position}'")
        String.trim(position)
      _ ->
        IO.puts("No position found")
        nil
    end
  end

  defp find_name_by_format(text, _email, _phone, position) do
    IO.puts("=== FINDING JAPANESE NAME BY FORMAT ===")

    # Split into lines and normalize
    lines =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    IO.puts("All lines for name analysis:")
    Enum.with_index(lines, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Line #{index}: '#{line}'")
    end)

    # Helper predicates (mirror English exactly)
    has_letters? = fn line -> Regex.match?(~r/[A-Za-z\p{Hiragana}\p{Katakana}\p{Han}]/u, line) end
    is_email_line? = fn line -> String.contains?(line, "@") end
    is_phone_line? = fn line -> Regex.match?(~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/, line) end
    is_position_line? = fn line -> line == position end
    is_urlish? = fn line ->
      down = String.downcase(line)
      String.contains?(down, "www") or String.contains?(down, "http")
    end

    # Filter out obvious non-name lines (mirror English exactly)
    IO.puts("Filtering out email, phone, position, and non-letter lines...")
    filtered_lines = lines
    |> Enum.reject(fn line ->
      is_email_line?.(line) or is_phone_line?.(line) or is_position_line?.(line) or
      not has_letters?.(line) or is_urlish?.(line)
    end)

    IO.puts("Remaining lines after filtering:")
    Enum.with_index(filtered_lines, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Filtered line #{index}: '#{line}'")
    end)

    # Mirror English logic exactly - use the same sophisticated scoring system
    is_person_name_pattern? = fn line ->
      # Look for First Last pattern (capitalized first letter, rest can be lowercase or uppercase)
      # But exclude common job title words
      down = String.downcase(line)
      # English name patterns (including with initials)
      is_english_basic = Regex.match?(~r/^[A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+$/, line)
      is_english_with_initial = Regex.match?(~r/^[A-Z][A-Za-z]+\s+[A-Z]\.?\s+[A-Z][A-Za-z]+$/, line)
      is_english_multiple_initials = Regex.match?(~r/^[A-Z][A-Za-z]+(\s+[A-Z]\.?)+\s+[A-Z][A-Za-z]+$/, line)
      is_english_with_title = Regex.match?(~r/^[A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+,\s*[A-Z]\.?[A-Z]?\.?$/, line)

      # Japanese name patterns
      is_japanese_name = Regex.match?(~r/^[\p{Hiragana}\p{Katakana}\p{Han}]+[\s・][\p{Hiragana}\p{Katakana}\p{Han}]+$/u, line)

      is_name_pattern = is_english_basic or is_english_with_initial or is_english_multiple_initials or is_english_with_title or is_japanese_name

      # Japanese job title exclusions
      is_not_job_title = not Enum.any?([
        "教授", "部長", "課長", "社長", "取締役", "理事", "院長", "主任", "係長", "次長",
        "専務", "常務", "代表", "責任者", "担当", "マネージャー", "ディレクター", "アドバイザー",
        "産婦人科", "内科", "外科", "小児科", "眼科", "耳鼻科", "皮膚科", "精神科",
        "整形外科", "泌尿器科", "婦人科", "産科", "大学", "学校", "研究所", "財団",
        "病院", "銀行", "保険", "法律", "不動産", "株式会社", "有限会社", "合同会社"
      ], &String.contains?(down, &1))

      is_name_pattern and is_not_job_title
    end

    # Check for lines that are clearly not names (general patterns)
    has_digits? = fn line -> Regex.match?(~r/\d/, line) end
    contains_url? = fn line ->
      down = String.downcase(line)
      String.contains?(down, "www") or String.contains?(down, "http") or String.contains?(down, ".com")
    end
    looks_like_address? = fn line ->
      # Check for address patterns
      String.contains?(line, "〒") or String.contains?(line, "市") or String.contains?(line, "県") or
      String.contains?(line, "区") or String.contains?(line, "町") or String.contains?(line, "番地")
    end

    # Score each line with the same logic as English
    name_candidates =
      filtered_lines
      |> Enum.with_index()
      |> Enum.map(fn {line, idx} ->
        base = 0
        base = if is_person_name_pattern?.(line), do: base + 8, else: base  # Strongly prefer person name patterns
        base = if not has_digits?.(line), do: base + 2, else: base
        base = if String.length(line) in 3..40, do: base + 1, else: base
        # Prefer top lines on the card, but not as strongly
        base = if idx <= 3, do: base + 2, else: base
        # Penalize things that look like addresses/URLs
        base = if contains_url?.(line), do: base - 5, else: base
        base = if looks_like_address?.(line), do: base - 4, else: base

        IO.puts("  Analyzing line: '#{line}' (index: #{idx})")
        IO.puts("    Is person name pattern: #{is_person_name_pattern?.(line)}")
        IO.puts("    Has digits: #{has_digits?.(line)}")
        IO.puts("    Contains URL: #{contains_url?.(line)}")
        IO.puts("    Looks like address: #{looks_like_address?.(line)}")
        IO.puts("    Final score: #{base}")

        {base, line, idx}
      end)
      |> Enum.filter(fn {score, _line, _idx} -> score > 0 end)
      |> Enum.sort_by(fn {score, _line, _idx} -> -score end)
      |> Enum.map(fn {_score, line, _idx} -> line end)

    IO.puts("Name candidates found: #{length(name_candidates)}")
    Enum.with_index(name_candidates, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Candidate #{index}: '#{line}'")
    end)

    case name_candidates do
      [name | _] ->
        IO.puts("Found name: '#{name}'")
        String.trim(name)
      _ ->
              IO.puts("No name found")
              nil
    end
  end

  defp find_company_by_keywords(text, _email, _phone, position, name) do
    IO.puts("=== FINDING JAPANESE COMPANY BY KEYWORDS ===")

    # Split into lines and normalize
    lines =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    IO.puts("All lines for company analysis:")
    Enum.with_index(lines, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Line #{index}: '#{line}'")
    end)

    # Company keywords (Japanese equivalents)
    company_keywords = [
      # English terms (for mixed language cards)
      "ltd", "limited", "inc", "incorporated", "corp", "corporation", "company", "co",
      "llc", "gmbh", "srl", "spa", "bv", "sa", "plc", "center", "centre", "university",
      "college", "school", "institute", "foundation", "hospital", "clinic", "bank",
      "insurance", "consulting", "group", "international", "global", "systems",
      "solutions", "technologies", "technology", "tech", "services", "enterprises",
      "associates", "partners", "holdings", "industries", "manufacturing", "production",
      "retail", "store", "shop", "restaurant", "cafe", "hotel", "law", "legal",
      "real estate", "media", "communications", "entertainment", "sports", "non-profit",
      # Japanese equivalents
      "株式会社", "有限会社", "合同会社", "合資会社", "合名会社", "一般社団法人", "一般財団法人",
      "公益社団法人", "公益財団法人", "学校法人", "医療法人", "社会福祉法人", "宗教法人",
      "NPO法人", "特定非営利活動法人", "大学", "学校", "研究所", "財団", "病院", "クリニック",
      "診療所", "銀行", "金融", "保険", "コンサルティング", "グループ", "インターナショナル",
      "グローバル", "システムズ", "ソリューションズ", "テクノロジーズ", "テクノロジー",
      "テック", "サービス", "エンタープライズ", "アソシエイツ", "パートナーズ", "ホールディングス",
      "インダストリーズ", "製造", "生産", "小売", "店舗", "ショップ", "レストラン", "カフェ",
      "ホテル", "法律", "法律事務所", "不動産", "メディア", "コミュニケーションズ",
      "エンターテイメント", "スポーツ", "非営利"
    ]

    # Helper predicates (mirror English exactly)
    has_letters? = fn line -> Regex.match?(~r/[A-Za-z\p{Hiragana}\p{Katakana}\p{Han}]/u, line) end
    is_email_line? = fn line -> String.contains?(line, "@") end
    is_phone_line? = fn line -> Regex.match?(~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/, line) end
    is_position_line? = fn line -> line == position end
    is_name_line? = fn line -> line == name end
    is_urlish? = fn line ->
      down = String.downcase(line)
      String.contains?(down, "www") or String.contains?(down, "http")
    end

    # Filter out obvious non-company lines (mirror English exactly)
    IO.puts("Filtering out email, phone, position, name, and non-letter lines...")
    filtered_lines = lines
    |> Enum.reject(fn line ->
      is_email_line?.(line) or is_phone_line?.(line) or is_position_line?.(line) or
      is_name_line?.(line) or not has_letters?.(line) or is_urlish?.(line)
    end)

    IO.puts("Remaining lines after filtering:")
    Enum.with_index(filtered_lines, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Filtered line #{index}: '#{line}'")
    end)

    # Score each line as a company candidate (mirror English exactly)
    company_candidates =
      filtered_lines
      |> Enum.map(fn line ->
        down = String.downcase(line)
        contains_keywords = Enum.any?(company_keywords, &String.contains?(down, &1))
        looks_like_company = Regex.match?(~r/^[A-Z\p{Hiragana}\p{Katakana}\p{Han}][A-Za-z\p{Hiragana}\p{Katakana}\p{Han}\s&.-]{2,50}$/u, line) and
                            length(String.split(line, ~r/\s+/, trim: true)) in 1..5

        IO.puts("  Analyzing line: '#{line}'")
        IO.puts("    Contains keywords: #{contains_keywords}")
        IO.puts("    Looks like company: #{looks_like_company}")

        score = 0
        score = if contains_keywords, do: score + 5, else: score
        score = if looks_like_company, do: score + 1, else: score

        {score, line}
      end)
      |> Enum.filter(fn {score, _line} -> score > 0 end)
      |> Enum.sort_by(fn {score, _line} -> -score end)
      |> Enum.map(fn {_score, line} -> line end)

    IO.puts("Company candidates (sorted by score):")
    Enum.with_index(company_candidates, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Candidate #{index}: '#{line}'")
    end)

    case company_candidates do
      [company | _] ->
        IO.puts("Selected company: '#{company}'")
        String.trim(company)
      _ ->
        IO.puts("No company found")
        nil
    end
  end
end
