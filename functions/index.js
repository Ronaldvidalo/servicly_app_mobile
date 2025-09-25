// =================================================================
// --- 1. IMPORTACIONES Y CONFIGURACIÓN INICIAL ---
// =================================================================
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {MercadoPagoConfig, Preference} = require("mercadopago");
const stripePackage = require("stripe");

// Inicializa la app de Firebase UNA SOLA VEZ
admin.initializeApp();
const db = admin.firestore();

// Define la región para TODAS las funciones de una vez
setGlobalOptions({region: "southamerica-east1"});

// =================================================================
// --- 2. NUEVA FUNCIÓN: MANTENER KEYWORDS DE BÚSQUEDA ---
// Se activa al crear o actualizar un usuario para mantener su perfil "buscable".
// =================================================================
exports.updateUserKeywords = onDocumentUpdated("usuarios/{userId}", (event) => {
  const newData = event.data.after.data();
  const oldData = event.data.before.data();

  // Solo se ejecuta si el documento existe y si el nombre o las categorías han cambiado.
  // ✅ CORRECCIÓN: Se reemplazó "oldData?." por una comprobación compatible.
  if (event.data.after.exists && (
    newData.display_name !== (oldData && oldData.display_name) ||
            JSON.stringify(newData.userCategorias) !== JSON.stringify(oldData && oldData.userCategorias)
  )) {
    const keywords = new Set();

    // Añadir palabras del nombre de usuario
    if (newData.display_name) {
      newData.display_name.toLowerCase().split(" ").forEach((word) => {
        if (word) keywords.add(word);
      });
    }

    // Añadir palabras de las categorías
    if (newData.userCategorias && Array.isArray(newData.userCategorias)) {
      newData.userCategorias.forEach((category) => {
        category.toLowerCase().split(" ").forEach((word) => {
          if (word) keywords.add(word);
        });
      });
    }

    // Actualiza el documento con el nuevo array de keywords
    return event.data.after.ref.update({
      search_keywords: Array.from(keywords),
    });
  }

  // Si no hay cambios relevantes, no hace nada.
  return null;
});


// =================================================================
// --- 3. FUNCIONES DE NOTIFICACIONES (Tus funciones existentes) ---
// =================================================================

// Notificación para nuevos mensajes en chats de contratos
exports.sendContractChatMessageNotification =
    onDocumentCreated("chats/{contratoId}/messages/{messageId}", async (event) => {
      const messageData = event.data.data();
      if (!messageData) {
        console.log("No hay datos en el mensaje, saliendo.");
        return;
      }

      const {contratoId} = event.params;
      const senderId = messageData.senderId;

      const contratoRef = db.collection("contratos").doc(contratoId);
      const contratoDoc = await contratoRef.get();

      if (!contratoDoc.exists) {
        console.error(`El contrato ${contratoId} no existe. No se puede enviar notificación.`);
        return;
      }

      const contratoData = contratoDoc.data();
      const participants = [contratoData.clienteId, contratoData.proveedorId];
      const recipientId = participants.find((id) => id !== senderId);

      if (!recipientId) {
        console.log("No se encontró un destinatario válido.");
        return;
      }

      const recipientDoc = await db.collection("usuarios").doc(recipientId).get();
      if (!recipientDoc.exists) {
        console.error(`El destinatario ${recipientId} no existe.`);
        return;
      }

      const fcmTokens = recipientDoc.data().fcmTokens || [];
      if (fcmTokens.length === 0) {
        console.log(`El destinatario ${recipientId} no tiene tokens.`);
        return;
      }

      const senderDoc = await db.collection("usuarios").doc(senderId).get();
      const senderName = senderDoc.exists ? senderDoc.data().display_name : "Alguien";
      const messageText = messageData.texto || "Te ha enviado un adjunto.";

      const message = {
        notification: {
          title: `Nuevo mensaje de ${senderName}`,
          body: messageText,
        },
        data: {
          type: "NUEVO_MENSAJE_CONTRATO",
          contratoId: contratoId,
        },
        tokens: fcmTokens,
      };

      try {
        console.log(`Enviando notificación de chat de contrato a ${fcmTokens.length} token(s).`);
        return await admin.messaging().sendEachForMulticast(message);
      } catch (error) {
        console.error("Error al enviar notificación de chat de contrato:", error);
      }
    });

// Notificación para nuevos "Me Gusta" en un post
exports.sendLikeNotification = onDocumentUpdated("post/{postId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const likesBefore = before.likes || [];
  const likesAfter = after.likes || [];

  if (likesAfter.length > likesBefore.length) {
    const newLikerId = likesAfter.find((id) => !likesBefore.includes(id));
    if (!newLikerId) return;

    const postAuthorId = after.authorId;
    if (postAuthorId === newLikerId) return;

    const likerDoc = await db.collection("usuarios").doc(newLikerId).get();
    const likerName = likerDoc.exists ? likerDoc.data().display_name : "Alguien";

    const authorDoc = await db.collection("usuarios").doc(postAuthorId).get();
    if (!authorDoc.exists) return;

    const fcmTokens = authorDoc.data().fcmTokens || [];
    if (fcmTokens.length === 0) return;

    const message = {
      notification: {
        title: "¡A alguien le gustó tu post!",
        body: `${likerName} le ha dado "Me gusta" a tu publicación.`,
      },
      data: {postId: event.params.postId, type: "nuevo_like"},
      tokens: fcmTokens,
    };

    try {
      console.log(`Enviando notificación de like a ${fcmTokens.length} token(s).`);
      return await admin.messaging().sendEachForMulticast(message);
    } catch (error) {
      console.error("Error al enviar notificación de like:", error);
    }
  }
});

// Notificación para nuevos comentarios
exports.sendCommentNotification = onDocumentCreated("post/{postId}/comentarios/{commentId}", async (event) => {
  const commentData = event.data.data();
  const {postId} = event.params;
  const commenterId = commentData.userId;

  const postDoc = await db.collection("post").doc(postId).get();
  if (!postDoc.exists) return;
  const postAuthorId = postDoc.data().authorId;
  if (postAuthorId === commenterId) return;

  const commenterDoc = await db.collection("usuarios").doc(commenterId).get();
  const commenterName = commenterDoc.exists ? commenterDoc.data().display_name : "Alguien";

  const authorDoc = await db.collection("usuarios").doc(postAuthorId).get();
  if (!authorDoc.exists) return;

  const fcmTokens = authorDoc.data().fcmTokens || [];
  if (fcmTokens.length === 0) return;

  const message = {
    notification: {
      title: "¡Nuevo comentario en tu post!",
      body: `${commenterName} ha comentado tu publicación.`,
    },
    data: {postId: postId, type: "nuevo_comentario"},
    tokens: fcmTokens,
  };

  try {
    console.log(`Enviando notificación de comentario a ${fcmTokens.length} token(s).`);
    return await admin.messaging().sendEachForMulticast(message);
  } catch (error) {
    console.error("Error al enviar notificación de comentario:", error);
  }
});

// Notificación para nuevos seguidores
exports.sendFollowerNotification = onDocumentUpdated("usuarios/{followedId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const followersBefore = before.followers || [];
  const followersAfter = after.followers || [];

  if (followersAfter.length > followersBefore.length) {
    const newFollowerId = followersAfter.find((id) => !followersBefore.includes(id));
    if (!newFollowerId) return;

    const {followedId} = event.params;
    if (followedId === newFollowerId) return;

    const followerDoc = await db.collection("usuarios").doc(newFollowerId).get();
    const followerName = followerDoc.exists ? followerDoc.data().display_name : "Alguien";

    const fcmTokens = after.fcmTokens || [];
    if (fcmTokens.length === 0) return;

    const message = {
      notification: {
        title: "¡Tenés un nuevo seguidor!",
        body: `${followerName} ahora te sigue.`,
      },
      data: {profileId: newFollowerId, type: "nuevo_seguidor"},
      tokens: fcmTokens,
    };

    try {
      console.log(`Enviando notificación de seguidor a ${fcmTokens.length} token(s).`);
      return await admin.messaging().sendEachForMulticast(message);
    } catch (error) {
      console.error("Error al enviar notificación de seguidor:", error);
    }
  }
});

// Notificación para actualizaciones de estado en presupuestos
exports.notifyOnBudgetUpdate = onDocumentUpdated("presupuestos/{presupuestoId}", async (event) => {
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  if (beforeData.estado === afterData.estado) return;

  let titulo = "";
  let mensaje = "";
  let destinatarioId = "";
  const remitenteId = afterData.realizadoPor;
  const clienteId = afterData.userServicio;

  switch (afterData.estado) {
  case "ACEPTADO_POR_CLIENTE":
    titulo = "¡Presupuesto Aceptado! ✅";
    mensaje = `El cliente aceptó tu presupuesto para "${afterData.tituloPresupuesto}".`;
    destinatarioId = remitenteId;
    break;
  case "RECHAZADO_POR_CLIENTE":
    titulo = "Presupuesto Rechazado ❌";
    mensaje = `El cliente rechazó tu presupuesto para "${afterData.tituloPresupuesto}".`;
    destinatarioId = remitenteId;
    break;
  case "CONTRATO_GENERADO":
    titulo = "¡Trabajo Confirmado! 🤝";
    mensaje = `El proveedor confirmó el trabajo para "${afterData.tituloPresupuesto}".`;
    destinatarioId = clienteId;
    break;
  }

  if (!titulo || !destinatarioId) return;

  const recipientDoc = await db.collection("usuarios").doc(destinatarioId).get();
  if (!recipientDoc.exists) return;

  const fcmTokens = recipientDoc.data().fcmTokens || [];
  if (fcmTokens.length === 0) return;

  const message = {
    notification: {title: titulo, body: mensaje},
    data: {idReferencia: event.params.presupuestoId, tipo: "actualizacion_presupuesto"},
    tokens: fcmTokens,
  };

  try {
    console.log(`Enviando notificación de presupuesto a ${fcmTokens.length} token(s).`);
    return await admin.messaging().sendEachForMulticast(message);
  } catch (error) {
    console.error("Error al enviar notificación de presupuesto:", error);
  }
});

// Notificación a proveedores sobre nuevas solicitudes de servicio
exports.notifyRelevantProviders = onDocumentCreated("solicitudes/{solicitudId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const solicitudData = snapshot.data();
  const {solicitudId} = event.params;

  if (!solicitudData.categoria ||
        !solicitudData.pais ||
        !solicitudData.municipio ||
        !solicitudData.titulo ||
        !solicitudData.user_id) {
    console.error("Solicitud con datos incompletos, no se puede notificar.", solicitudData);
    return;
  }

  try {
    const providersQuery = db.collection("usuarios")
      .where("rol_user", "in", ["Proveedor", "Ambos"])
      .where("pais", "==", solicitudData.pais)
      .where("userCategorias", "array-contains", solicitudData.categoria);

    const querySnapshot = await providersQuery.get();
    if (querySnapshot.empty) {
      console.log(`No se encontraron proveedores para la categoría: ${solicitudData.categoria}`);
      return;
    }

    const providersToNotify = querySnapshot.docs.filter((doc) => {
      const providerData = doc.data();
      if (doc.id === solicitudData.user_id) return false;
      return Array.isArray(providerData.zonasDeNotificacion) &&
                providerData.zonasDeNotificacion.includes(solicitudData.municipio);
    });

    if (providersToNotify.length === 0) {
      console.log(`Ningún proveedor (que no sea el creador) trabaja en el Municipio: ${solicitudData.municipio}`);
      return;
    }

    for (const doc of providersToNotify) {
      const providerData = doc.data();
      const fcmTokens = providerData.fcmTokens || [];
      if (fcmTokens.length > 0) {
        const message = {
          notification: {
            title: `Nueva solicitud de ${solicitudData.categoria}`,
            body: `Hay un nuevo trabajo de "${solicitudData.titulo}" en tu zona que podría interesarte.`,
          },
          data: {idReferencia: solicitudId, tipo: "nueva_solicitud"},
          tokens: fcmTokens,
        };
        await admin.messaging().sendEachForMulticast(message);
        console.log(`Notificación enviada a proveedor ${doc.id}`);
      }
    }
  } catch (error) {
    console.error("Error en notifyRelevantProviders:", error);
  }
});

// Notificación al cliente cuando recibe un nuevo presupuesto
exports.notifyOnNewBudget = onDocumentCreated("presupuestos/{presupuestoId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const budgetData = snapshot.data();
  const clientId = budgetData.userServicio;
  const professionalId = budgetData.realizadoPor;

  if (!clientId || !professionalId) {
    console.error("Presupuesto sin cliente o profesional asignado.");
    return;
  }

  const professionalDoc = await db.collection("usuarios").doc(professionalId).get();
  const professionalName = professionalDoc.exists ? professionalDoc.data().display_name : "Un profesional";

  const clientDoc = await db.collection("usuarios").doc(clientId).get();
  if (!clientDoc.exists) {
    console.error(`El cliente ${clientId} no existe.`);
    return;
  }

  const fcmTokens = clientDoc.data().fcmTokens || [];
  if (fcmTokens.length === 0) {
    console.log(`El cliente ${clientId} no tiene tokens FCM.`);
    return;
  }

  const message = {
    notification: {
      title: "¡Has recibido un nuevo presupuesto!",
      body: `${professionalName} te ha enviado una oferta para tu solicitud: "${budgetData.tituloPresupuesto}".`,
    },
    data: {
      idReferencia: event.params.presupuestoId,
      tipo: "nuevo_presupuesto",
      idSolicitud: budgetData.idSolicitud,
    },
    tokens: fcmTokens,
  };

  try {
    console.log(`Enviando notificación de nuevo presupuesto a ${fcmTokens.length}
         token(s) para el cliente ${clientId}.`);
    return await admin.messaging().sendEachForMulticast(message);
  } catch (error) {
    console.error("Error al enviar notificación de nuevo presupuesto:", error);
  }
});


// =================================================================
// --- 4. FUNCIONES INVOCABLES (onCall) - (Tus funciones existentes) ---
// =================================================================

// Asigna un rol de admin a un usuario.
exports.setAdminRole = onCall(async (request) => {
  if (request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Solo un admin puede asignar roles.");
  }
  const email = request.data.email;
  if (!email) {
    throw new HttpsError("invalid-argument", "Se requiere un email.");
  }
  try {
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().setCustomUserClaims(user.uid, {admin: true});
    return {message: `Éxito! ${email} ahora es admin.`};
  } catch (error) {
    console.error("Error al asignar rol de admin:", error);
    throw new HttpsError("not-found", "No se encontró un usuario con ese email.");
  }
});

// Obtiene o crea un chat entre dos usuarios.
exports.getOrCreateChat = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Usuario no autenticado.");
  const currentUserId = request.auth.uid;
  const {otherUserId} = request.data;
  if (!otherUserId) throw new HttpsError("invalid-argument", "Falta otherUserId.");

  const participants = [currentUserId, otherUserId].sort();
  const chatId = participants.join("_");
  const chatRef = db.collection("chats").doc(chatId);
  const chatDoc = await chatRef.get();

  if (!chatDoc.exists) {
    await chatRef.set({participantes: participants});
    const [currentUserDoc, otherUserDoc] = await Promise.all([
      db.collection("usuarios").doc(currentUserId).get(),
      db.collection("usuarios").doc(otherUserId).get(),
    ]);
    const currentData = currentUserDoc.data() || {};
    const otherData = otherUserDoc.data() || {};
    await chatRef.update({
      participantesNombres: {
        [currentUserId]: currentData.display_name || "Usuario",
        [otherUserId]: otherData.display_name || "Usuario",
      },
      participantesFotos: {
        [currentUserId]: currentData.photo_url || "",
        [otherUserId]: otherData.photo_url || "",
      },
      ultimoMensaje: {
        texto: "Inicia la conversación...",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        idAutor: "",
      },
    });
  }
  return {chatId};
});

// Crea un link de onboarding para una cuenta de Stripe.
exports.createStripeAccountLink = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Usuario no autenticado.");
  }
  const stripeSecret = functions.config().stripe.secret;
  const stripe = stripePackage(stripeSecret);
  const userId = request.auth.uid;
  const userRef = admin.firestore().collection("usuarios").doc(userId);
  const userDoc = await userRef.get();
  const userData = userDoc.data();
  let accountId = userData.stripeAccountId;
  if (!accountId) {
    const account = await stripe.accounts.create({
      type: "express",
      email: userData.email,
    });
    accountId = account.id;
    await userRef.update({stripeAccountId: accountId});
  }
  const accountLink = await stripe.accountLinks.create({
    account: accountId,
    refresh_url: "https://servicly.app/reauth",
    return_url: "https://servicly.app/success",
    type: "account_onboarding",
  });
  return {url: accountLink.url};
});

// Crea una preferencia de pago en Mercado Pago.
exports.crearPreferenciaMP = onCall({enforceAppCheck: false}, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Usuario no autenticado.");
  const {title, unitPrice, payerEmail} = req.data;
  if (!title || !unitPrice || !payerEmail) throw new HttpsError("invalid-argument", "Faltan datos.");

  const client = new MercadoPagoConfig({accessToken: functions.config().mercadopago.token});
  const preference = new Preference(client);
  try {
    const response = await preference.create({
      body: {
        items: [{
          title: title,
          quantity: 1,
          currency_id: "ARS",
          unit_price: Number(unitPrice),
        }],
        payer: {email: payerEmail},
        back_urls: {
          success: "https://servicly.app/pago-exitoso",
          failure: "https://servicly.app/pago-fallido",
          pending: "https://servicly.app/pago-pendiente",
        },
        auto_return: "approved",
      },
    });
    return {preferenceId: response.id, initPoint: response.init_point};
  } catch (error) {
    console.error("Error al crear preferencia en MP:", error);
    throw new HttpsError("unknown", "No se pudo crear el pago.", error);
  }
});
