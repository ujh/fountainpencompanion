class AdminMailer < ApplicationMailer
  def agent_mail(subject, body)
    @body = body
    mail(to: "hello@fountainpencompanion.com", subject: subject)
  end

  def ink_review_report(ink_review, user, description)
    @ink_review = ink_review
    @ink = ink_review.macro_cluster
    @user = user
    @description = description
    mail(
      to: "hello@fountainpencompanion.com",
      reply_to: user.email,
      subject: "Review reported: #{ink_review.title}"
    )
  end

  def ink_report(ink, user, description)
    @ink = ink
    @user = user
    @description = description
    mail(
      to: "hello@fountainpencompanion.com",
      reply_to: user.email,
      subject: "Ink error reported: #{ink.name}"
    )
  end

  def pen_model_report(pen_model, user, description)
    @pen_model = pen_model
    @user = user
    @description = description
    mail(
      to: "hello@fountainpencompanion.com",
      reply_to: user.email,
      subject: "Pen model error reported: #{pen_model.name}"
    )
  end

  def pen_variant_report(pen_variant, user, description)
    @pen_variant = pen_variant
    @user = user
    @description = description
    mail(
      to: "hello@fountainpencompanion.com",
      reply_to: user.email,
      subject: "Pen variant error reported: #{pen_variant.name}"
    )
  end

  def patreon_badges_to_deliver(users)
    @users = users
    mail(
      to: "hello@fountainpencompanion.com",
      subject: "#{users.size} Patreon badge(s) to mark delivered"
    )
  end
end
