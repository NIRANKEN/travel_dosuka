import { Request, Response, NextFunction } from "express";
import { getAuth } from "firebase-admin/auth";

export async function authMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({ error: "認証が必要です。Authorization: Bearer <token> ヘッダーを付けてください" });
    return;
  }

  const token = authHeader.split("Bearer ")[1];
  try {
    const decoded = await getAuth().verifyIdToken(token);
    req.uid = decoded.uid;
    next();
  } catch {
    res.status(401).json({ error: "無効な認証トークンです" });
  }
}
