
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import OpenAI from 'https://esm.sh/openai@4';
import { corsHeaders } from '../_shared/cors.ts';

const json = (body: unknown, status = 200) =>
  Response.json(body, {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const authorization = req.headers.get('Authorization');
  if (!authorization) {
    return json({ error: 'Sign in is required.' }, 401);
  }

  const apiKey = Deno.env.get('OPENAI_API_KEY');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');

  if (!apiKey || !supabaseUrl || !anonKey) {
    return json({ error: 'Cloud configuration is incomplete.' }, 503);
  }

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });

  const { data: { user }, error: authError } =
    await supabase.auth.getUser();

  if (authError || !user) {
    return json({ error: 'Invalid session.' }, 401);
  }

  let input: Record<string, unknown>;

  try {
    input = await req.json();
  } catch {
    return json({ error: 'Invalid JSON request.' }, 400);
  }

  const request = input.request;
  const subject = input.subject;
  const proficiency = input.proficiency;
  const language = input.language;

  if (
    typeof request !== 'string' ||
    request.trim().length < 3 ||
    request.trim().length > 500
  ) {
    return json({ error: 'Request must contain 3–500 characters.' }, 400);
  }

  if (
    typeof subject !== 'string' ||
    subject.length > 80 ||
    typeof proficiency !== 'string' ||
    !['Beginner', 'Developing', 'Intermediate', 'Proficient']
      .includes(proficiency) ||
    typeof language !== 'string' ||
    !['en', 'fil', 'ilo'].includes(language)
  ) {
    return json({ error: 'Invalid subject, proficiency, or language.' }, 400);
  }

  const fields =
    'id,title,description,subject,topic,language,difficulty,author_organization,original_source_url,license_name,redistribution_allowed,review_status,external_url';

  let resources: Record<string, unknown>[] = [];
  const lookup = await supabase
    .from('resources')
    .select(fields)
    .eq('is_published', true)
    .eq('subject', subject)
    .eq('language', language)
    .limit(50);

  if (lookup.error) {
    return json({ error: 'Catalogue lookup failed.' }, 500);
  }

  resources = lookup.data ?? [];

  const languageName = {
    en: 'English',
    fil: 'Filipino',
    ilo: 'Ilocano',
  }[language];

  try {
    const openai = new OpenAI({ apiKey });

    const completion = await openai.chat.completions.create({
      model: Deno.env.get('OPENAI_MODEL') || 'gpt-4o-mini',
      response_format: { type: 'json_object' },
      messages: [
        {
          role: 'system',
          content: `
You are TULAI, an educational learning assistant.

Create a complete, readable learning lesson based on the learner's request.

Write in ${languageName}.
Adapt the explanation to the learner's proficiency level.

Return valid JSON with these exact keys:

{
  "title": "Lesson title",
  "introduction": "Short introduction",
  "learning_objectives": ["Objective 1", "Objective 2"],
  "sections": [
    {
      "heading": "Section heading",
      "content": "Detailed educational explanation",
      "examples": ["Example 1", "Example 2"]
    }
  ],
  "practice_questions": [
    {
      "question": "Question",
      "options": ["A", "B", "C", "D"],
      "correct_answer": "A",
      "explanation": "Explanation"
    }
  ],
  "summary": "Lesson summary"
}

Requirements:
- Always provide actual lesson content.
- Never return empty sections.
- Include at least two lesson sections.
- Include at least three practice questions.
- Explain concepts clearly with examples.
- Do not invent official TESDA or DepEd endorsements.
- Treat catalogue records as suggestions, not proof that a lesson is verified.
- Never invent source URLs or licenses.
- This is AI-generated educational material, not a formal qualification.
          `,
        },
        {
          role: 'user',
          content: JSON.stringify({
            request: request.trim(),
            subject,
            proficiency,
            language,
            available_catalogue_resources: resources,
          }),
        },
      ],
    });

    const raw = completion.choices[0]?.message?.content;

    if (!raw) {
      return json({ error: 'AI returned an empty response.' }, 502);
    }

    const lesson = JSON.parse(raw);

    if (
      typeof lesson.title !== 'string' ||
      typeof lesson.introduction !== 'string' ||
      !Array.isArray(lesson.sections) ||
      lesson.sections.length < 2 ||
      typeof lesson.summary !== 'string'
    ) {
      return json({ error: 'AI returned incomplete lesson content.' }, 502);
    }

    return json({
      success: true,
      generated_draft: {
        ...lesson,
        status: 'AI-generated and unverified',
      },
      existing_resources: resources,
      label: 'AI-generated and unverified',
    });

  } catch (error) {
    console.error('AI lesson generation failed:', error);
    return json({
      error: 'AI lesson generation failed. Please try again.',
    }, 502);
  }
});
