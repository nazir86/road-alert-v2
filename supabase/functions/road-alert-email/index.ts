import { createClient } from "npm:@supabase/supabase-js@2";

function env(name) {
  return Deno.env.get(name) ?? "";
}

function secretKey() {
  const keys = env("SUPABASE_SECRET_KEYS");
  if (keys) {
    return JSON.parse(keys).default;
  }
  return env("SUPABASE_SERVICE_ROLE_KEY");
}

function assertOk(result) {
  if (result.error) throw result.error;
  return result.data;
}

async function sendEmail(to, subject, text, uniqueKey) {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env("RESEND_API_KEY")}`,
      "Content-Type": "application/json",
      "Idempotency-Key": uniqueKey,
    },
    body: JSON.stringify({
      from: env("ROAD_ALERT_FROM"),
      to: [to],
      subject,
      text,
    }),
  });

  const result = await response.text();

  if (!response.ok) {
    throw new Error(`Resend ${response.status}: ${result}`);
  }

  return result;
}

async function processQueue(db) {
  const jobs = assertOk(
    await db.rpc("road_claim_email_jobs", { p_limit: 10 }),
  ) ?? [];

  let sent = 0;
  let failed = 0;

  for (const job of jobs) {
    try {
      const report = assertOk(
        await db.from("reports")
          .select("id,type,severity,latitude,longitude")
          .eq("id", job.report_id)
          .single(),
      );

      let recipient;
      let subject;
      let message;

      if (job.kind === "new_report") {
        recipient = env("ROAD_ALERT_AGENT_EMAIL");

        subject = report.severity === "grave"
          ? "ROAD ALERT - Signalement grave"
          : "ROAD ALERT - Nouveau signalement";

        message = [
          "Un nouveau signalement a ete recu.",
          "",
          `Type : ${report.type}`,
          `Gravite : ${report.severity}`,
          `Latitude : ${report.latitude}`,
          `Longitude : ${report.longitude}`,
          `Reference : ${report.id}`,
        ].join("\n");
      } else {
        const userResult = await db.auth.admin.getUserById(
          job.target_user,
        );

        if (userResult.error) throw userResult.error;

        recipient = userResult.data.user?.email;

        subject = "ROAD ALERT - Mise a jour du signalement";

        message = [
          "Le statut de votre signalement a change.",
          "",
          `Reference : ${report.id}`,
          `Ancien statut : ${job.old_status ?? "Non defini"}`,
          `Nouveau statut : ${job.new_status}`,
        ].join("\n");
      }

      if (!recipient) {
        throw new Error("Email destinataire non configure.");
      }

      await sendEmail(
        recipient,
        subject,
        message,
        `road-alert-${job.event_key}`,
      );

      assertOk(
        await db.from("road_email_queue")
          .update({
            sent_at: new Date().toISOString(),
            last_error: null,
          })
          .eq("event_key", job.event_key)
          .select("event_key"),
      );

      sent++;
    } catch (error) {
      failed++;

      const delayMinutes = Math.min(
        60,
        2 ** Math.min(job.attempts, 5),
      );

      await db.from("road_email_queue")
        .update({
          last_error: String(error).slice(0, 1000),
          next_attempt_at: new Date(
            Date.now() + delayMinutes * 60000,
          ).toISOString(),
        })
        .eq("event_key", job.event_key);
    }
  }

  return { processed: jobs.length, sent, failed };
}

async function countReports(db, from, to, field, value) {
  let query = db.from("reports")
    .select("id", { count: "exact", head: true })
    .gte("created_at", from)
    .lt("created_at", to);

  if (field) query = query.eq(field, value);

  const result = await query;
  if (result.error) throw result.error;
  return result.count ?? 0;
}

async function weeklyReport(db) {
  const end = new Date();
  const daysSinceMonday = (end.getUTCDay() + 6) % 7;
  end.setUTCDate(end.getUTCDate() - daysSinceMonday);
  end.setUTCHours(0, 0, 0, 0);

  const start = new Date(end.getTime() - 7 * 86400000);
  const weekKey = start.toISOString().slice(0, 10);

  const claimed = assertOk(
    await db.rpc("road_claim_weekly_email", { p_week: weekKey }),
  );

  if (!claimed) {
    return { skipped: true, reason: "Deja envoye ou en attente" };
  }

  try {
    const from = start.toISOString();
    const to = end.toISOString();

    const total = await countReports(db, from, to);
    const severe = await countReports(db, from, to, "severity", "grave");
    const potholes = await countReports(db, from, to, "type", "nid_de_poule");
    const cracks = await countReports(db, from, to, "type", "fissure");
    const subsidence = await countReports(db, from, to, "type", "affaissement");
    const inProgress = await countReports(db, from, to, "status", "en_cours");
    const repaired = await countReports(db, from, to, "status", "repare");

    const message = [
      "ROAD ALERT - Rapport hebdomadaire",
      `Periode UTC : ${weekKey} au ${end.toISOString().slice(0, 10)}`,
      "",
      `Signalements crees : ${total}`,
      `Signalements graves : ${severe}`,
      `Nids-de-poule : ${potholes}`,
      `Fissures : ${cracks}`,
      `Affaissements : ${subsidence}`,
      `En cours : ${inProgress}`,
      `Repares : ${repaired}`,
      "",
      "Rapport genere automatiquement par ROAD ALERT.",
    ].join("\n");

    const recipient =
      env("ROAD_ALERT_REPORT_EMAIL") ||
      env("ROAD_ALERT_AGENT_EMAIL");

    if (!recipient) throw new Error("Email du rapport non configure.");

    await sendEmail(
      recipient,
      `ROAD ALERT - Rapport semaine ${weekKey}`,
      message,
      `road-alert-weekly-${weekKey}`,
    );

    assertOk(
      await db.from("road_weekly_email_runs")
        .update({
          sent_at: new Date().toISOString(),
          last_error: null,
        })
        .eq("week_key", weekKey)
        .select("week_key"),
    );

    return { sent: true, week: weekKey, total };
  } catch (error) {
    await db.from("road_weekly_email_runs")
      .update({
        last_error: String(error).slice(0, 1000),
        next_attempt_at: new Date(Date.now() + 600000).toISOString(),
      })
      .eq("week_key", weekKey);

    throw error;
  }
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const configuredToken = env("ROAD_ALERT_MAIL_TOKEN");
  const receivedToken = request.headers.get("x-road-alert-token");

  if (!configuredToken ||
      configuredToken.length < 32 ||
      receivedToken !== configuredToken) {
    return new Response("Unauthorized", { status: 401 });
  }

  if (!env("RESEND_API_KEY") || !env("ROAD_ALERT_FROM") ||
      !env("SUPABASE_URL") || !secretKey()) {
    return Response.json(
      { error: "Configuration serveur incomplete" },
      { status: 503 },
    );
  }

  try {
    const body = await request.json();
    const mode = body?.mode;

    if (mode !== "notifications" && mode !== "weekly") {
      return Response.json(
        { error: "Mode inconnu" },
        { status: 400 },
      );
    }

    const db = createClient(env("SUPABASE_URL"), secretKey(), {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const result = mode === "weekly"
      ? await weeklyReport(db)
      : await processQueue(db);

    return Response.json({ ok: true, ...result });
  } catch (error) {
    return Response.json(
      { ok: false, error: String(error) },
      { status: 500 },
    );
  }
});
