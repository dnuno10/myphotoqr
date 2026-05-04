// supabase/functions/stripe-webhook/index.ts

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@16.12.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-06-20",
});

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

serve(async (req) => {
  const signature = req.headers.get("stripe-signature");

  if (!signature) {
    return new Response("Missing Stripe signature", { status: 400 });
  }

  const body = await req.text();

  let event: Stripe.Event;

  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      Deno.env.get("STRIPE_WEBHOOK_SECRET")!,
    );
  } catch (error) {
    return new Response(`Webhook signature verification failed: ${error.message}`, {
      status: 400,
    });
  }

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;

        const subscriptionId = session.subscription as string | null;
        const customerId = session.customer as string | null;
        const userId =
          session.metadata?.supabase_user_id ??
          session.client_reference_id;

        if (!subscriptionId || !customerId || !userId) break;

        const subscription = await stripe.subscriptions.retrieve(subscriptionId);

        await upsertSubscription({
          userId,
          customerId,
          subscription,
        });

        break;
      }

      case "customer.subscription.updated":
      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;
        const customerId = subscription.customer as string;

        const userId = subscription.metadata?.supabase_user_id;

        if (!userId) {
          const { data: profile } = await supabase
            .from("profiles")
            .select("id")
            .eq("stripe_customer_id", customerId)
            .maybeSingle();

          if (!profile?.id) break;

          await upsertSubscription({
            userId: profile.id,
            customerId,
            subscription,
          });
        } else {
          await upsertSubscription({
            userId,
            customerId,
            subscription,
          });
        }

        break;
      }

      case "invoice.paid":
      case "invoice.payment_failed": {
        const invoice = event.data.object as Stripe.Invoice;

        const subscriptionId =
          typeof invoice.subscription === "string"
            ? invoice.subscription
            : invoice.subscription?.id;

        if (!subscriptionId) break;

        const subscription = await stripe.subscriptions.retrieve(subscriptionId);
        const customerId = subscription.customer as string;

        const { data: profile } = await supabase
          .from("profiles")
          .select("id")
          .eq("stripe_customer_id", customerId)
          .maybeSingle();

        if (!profile?.id) break;

        await upsertSubscription({
          userId: profile.id,
          customerId,
          subscription,
        });

        break;
      }

      default:
        break;
    }

    return Response.json({ received: true });
  } catch (error) {
    return Response.json(
      {
        error: error.message ?? "Webhook handler failed",
      },
      { status: 500 },
    );
  }
});

async function upsertSubscription({
  userId,
  customerId,
  subscription,
}: {
  userId: string;
  customerId: string;
  subscription: Stripe.Subscription;
}) {
  const item = subscription.items.data[0];
  const price = item?.price;
  const productId =
    typeof price?.product === "string" ? price.product : price?.product?.id;

  await supabase.from("subscriptions").upsert(
    {
      user_id: userId,
      stripe_customer_id: customerId,
      stripe_subscription_id: subscription.id,
      stripe_product_id: productId,
      stripe_price_id: price?.id,
      status: subscription.status,
      current_period_end: new Date(
        subscription.current_period_end * 1000,
      ).toISOString(),
      updated_at: new Date().toISOString(),
    },
    {
      onConflict: "stripe_subscription_id",
    },
  );

  await supabase.from("profiles").upsert({
    id: userId,
    stripe_customer_id: customerId,
    updated_at: new Date().toISOString(),
  });
}