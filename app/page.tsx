export default function Home() {
  return (
    <main className="container">
      <h1>Visconde Backend API</h1>
      <p>Projeto Next.js com TypeScript + Prisma (PostgreSQL).</p>
      <p>Endpoints iniciais:</p>
      <ul>
        <li>
          <code>GET /api/health</code>
        </li>
        <li>
          <code>GET /api/users</code>
        </li>
        <li>
          <code>POST /api/users</code>
        </li>
      </ul>
    </main>
  );
}
