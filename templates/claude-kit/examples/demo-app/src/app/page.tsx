import { SplitForm } from "./split-form";

export default function Home() {
  return (
    <main>
      <h1>Split</h1>
      <p>One expense per line, for example: Alice paid 30.50 for Alice, Bob, Carol</p>
      <SplitForm />
    </main>
  );
}
